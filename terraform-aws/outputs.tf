output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "region" {
  value = var.region
}

output "ecr_registry" {
  description = "Set this as images.repository in Helm"
  value       = module.ecr.registry
}

output "ecr_repo_urls" {
  description = "Full URL per service repo"
  value       = module.ecr.repo_urls
}

output "github_actions_role_arn" {
  description = "Add this to GitHub Secrets as AWS_ROLE_ARN"
  value       = module.github_oidc.role_arn
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "argocd_ui_command" {
  description = "Run this to get the ArgoCD web UI URL after terraform apply"
  value       = "kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "argocd_initial_password_command" {
  description = "Run this to get the ArgoCD admin initial password"
  value       = "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
}
