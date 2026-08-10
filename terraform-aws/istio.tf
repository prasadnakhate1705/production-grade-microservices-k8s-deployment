# ─────────────────────────────────────────────────────────────────────────────
# ISTIO INSTALLATION — 3 Helm releases in strict order
#
# 1. istio-base    — CRDs (VirtualService, Gateway, ServiceEntry, etc.)
# 2. istiod        — Control plane (config, certificates, sidecar injection)
# 3. istio-ingress — IngressGateway (the LoadBalancer pod at the cluster edge)
#
# All three land on system nodes via nodeSelector + toleration.
# ─────────────────────────────────────────────────────────────────────────────

# CRDs is custom resource definitions, which enable custom Kubernetes objects like VirtualService, Gateway, ServiceEntry, etc. These must be installed before the istiod control plane, which relies on them to function properly. The istio-base Helm release is responsible for installing these CRDs into the cluster.
# Step 1 — CRDs: must exist before istiod starts
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_version
  namespace        = "istio-system"
  create_namespace = false # already created in namespaces.tf

  depends_on = [kubernetes_namespace.istio_system]
}

# Step 2 — istiod: the control plane
# Pinned to system nodes via nodeSelector + toleration for dedicated=system taint
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  set {
    name  = "pilot.nodeSelector.role"
    value = "system"
  }

  set {
    name  = "pilot.tolerations[0].key"
    value = "dedicated"
  }

  set {
    name  = "pilot.tolerations[0].value"
    value = "system"
  }

  set {
    name  = "pilot.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Wait until istiod deployment is healthy before proceeding
  wait    = true
  timeout = 300

  depends_on = [helm_release.istio_base]
}

# Step 3 — Ingress Gateway: the entry point for external traffic
# Runs on system nodes, exposes an AWS NLB (Network Load Balancer)
resource "helm_release" "istio_ingress" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-system"

  set {
    name  = "nodeSelector.role"
    value = "system"
  }

  set {
    name  = "tolerations[0].key"
    value = "dedicated"
  }

  set {
    name  = "tolerations[0].value"
    value = "system"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # AWS NLB annotation — creates a Network Load Balancer instead of Classic ELB
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  wait    = true
  timeout = 300

  depends_on = [helm_release.istiod]
}
