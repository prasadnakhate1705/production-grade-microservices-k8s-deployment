output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "API server endpoint — used by the kubernetes provider"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA cert — used by the kubernetes provider"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL — used by the Helm provider and IRSA"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
