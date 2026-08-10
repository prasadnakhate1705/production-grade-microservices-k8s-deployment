# ─────────────────────────────────────────────────────────────────────────────
# KUBERNETES NAMESPACES
#
# istio-system    — Istio control plane (istiod + ingressgateway). Created here
#                   because istiod (istio.tf) must install into it.
# e-commerce-app  — The 11 microservices namespace is NOT created here. ArgoCD
#                   owns it: the Application sets CreateNamespace=true plus
#                   managedNamespaceMetadata istio-injection=enabled, so the
#                   namespace is created already labeled for sidecar injection.
#                   Managing it in two places (here + ArgoCD) would conflict.
# argocd          — created separately in argocd.tf via kubectl
# kube-system     — auto-created by EKS
# ─────────────────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }

  depends_on = [module.eks]
}
