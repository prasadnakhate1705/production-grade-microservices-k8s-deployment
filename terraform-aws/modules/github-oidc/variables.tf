variable "github_repo" {
  type        = string
  description = "GitHub repo in owner/name format — e.g. prasadnakhate/microservices-demo"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name — used in IAM policy to scope EKS access"
}

variable "ecr_registry" {
  type        = string
  description = "ECR registry URL — used to scope ECR push permissions"
}
