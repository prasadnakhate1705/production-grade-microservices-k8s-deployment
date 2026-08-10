# ─────────────────────────────────────────────────────────────────────────────
# ARGOCD INSTALLATION
# Installs ArgoCD into the EKS cluster and registers our Helm chart as an
# Application so ArgoCD auto-deploys whenever values.yaml changes in git.
#
# Sequence:
#   1. Create argocd namespace
#   2. Install ArgoCD from official stable manifest
#   3. Wait for ArgoCD server to be ready
#   4. Generate Application manifest (substituting ECR registry + GitHub repo)
#   5. Apply Application → ArgoCD starts watching the helm-chart/ folder
# ─────────────────────────────────────────────────────────────────────────────

# Step 1 + 2 + 3 — install ArgoCD
resource "null_resource" "install_argocd" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      echo "── Creating argocd namespace..."
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

      echo "── Installing ArgoCD (stable release)..."
      kubectl apply -n argocd \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

      echo "── Waiting for ArgoCD server to become available (up to 5 min)..."
      kubectl wait deployment argocd-server \
        --for=condition=available \
        --timeout=300s \
        -n argocd

      echo "── ArgoCD installed successfully."
    EOT
  }

  # Must run after cluster is ready and kubeconfig is configured
  depends_on = [
    module.eks,
    null_resource.update_kubeconfig
  ]
}

# Step 3b — pin every ArgoCD workload onto the system nodes
# The upstream install.yaml sets no nodeSelector/toleration, so by default
# ArgoCD lands on the (untainted) app nodes alongside the microservices. We
# patch all ArgoCD Deployments + the application-controller StatefulSet with:
#   nodeSelector role=system  → forces them onto system nodes
#   toleration dedicated=system → lets them past the system node taint
resource "null_resource" "pin_argocd_to_system" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      PATCH='{"spec":{"template":{"spec":{"nodeSelector":{"role":"system"},"tolerations":[{"key":"dedicated","operator":"Equal","value":"system","effect":"NoSchedule"}]}}}}'

      echo "── Pinning ArgoCD Deployments to system nodes..."
      for d in $(kubectl get deploy -n argocd -o name); do
        kubectl patch -n argocd "$d" --type merge -p "$PATCH"
      done

      echo "── Pinning ArgoCD application-controller StatefulSet to system nodes..."
      kubectl patch statefulset argocd-application-controller -n argocd --type merge -p "$PATCH"

      echo "── Waiting for ArgoCD to reschedule onto system nodes..."
      kubectl rollout status deployment argocd-server -n argocd --timeout=300s

      echo "── ArgoCD is now pinned to system nodes."
    EOT
  }

  depends_on = [null_resource.install_argocd]
}

# Step 4 + 5 — generate the Application manifest and apply it
# Uses sed to replace the two placeholders in application.yaml.tpl:
#   REPLACE_GITHUB_REPO   → e.g. prasadnakhate/microservices-demo
#   REPLACE_ECR_REGISTRY  → e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com
resource "null_resource" "apply_argocd_application" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      echo "── Generating ArgoCD Application manifest..."
      sed \
        -e 's|REPLACE_GITHUB_REPO|${var.github_repo}|g' \
        -e 's|REPLACE_ECR_REGISTRY|${module.ecr.registry}|g' \
        ${path.module}/../argocd/application.yaml.tpl \
        > /tmp/argocd-application.yaml

      echo "── Applying ArgoCD Application..."
      kubectl apply -f /tmp/argocd-application.yaml

      echo "── Done. ArgoCD is now watching helm-chart/ in ${var.github_repo}"
    EOT
  }

  # Istio must be fully up before ArgoCD syncs the chart: istio_ingress chains
  # istiod + istio_base (CRDs), so the Gateway/VirtualService CRs are valid and
  # the injection webhook is ready to add sidecars to the microservice pods.
  depends_on = [
    null_resource.pin_argocd_to_system,
    helm_release.istio_ingress,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# ARGOCD SERVER — expose via LoadBalancer so you can access the UI
# By default ArgoCD server is ClusterIP (only reachable inside cluster).
# This patches it to LoadBalancer so you get a public URL for the web UI.
# ─────────────────────────────────────────────────────────────────────────────
resource "null_resource" "expose_argocd_ui" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      echo "── Exposing ArgoCD UI via LoadBalancer..."
      kubectl patch svc argocd-server \
        -n argocd \
        -p '{"spec": {"type": "LoadBalancer"}}'
      echo "── ArgoCD UI will be available at the LoadBalancer hostname shortly."
      echo "── Run: kubectl get svc argocd-server -n argocd"
    EOT
  }

  depends_on = [null_resource.install_argocd]
}
