# e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com
# This is what goes into helm --set images.repository=...
output "registry" {
  description = "ECR registry URL (account.dkr.ecr.region.amazonaws.com)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

# Full repo URLs keyed by service name — useful for CI scripts
output "repo_urls" {
  description = "Map of service name to full ECR repo URL"
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}
