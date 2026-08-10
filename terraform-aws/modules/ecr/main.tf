# One repo per service — names match helm chart service names exactly
# e.g. "adservice", "frontend", "cartservice" ...
resource "aws_ecr_repository" "services" {
  for_each = toset(var.service_names)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # AWS scans every pushed image for known CVEs
  }

  tags = {
    cluster = var.cluster_name
  }
}

# Lifecycle policy: keep only the 10 most recent images per repo
# Prevents ECR storage costs from ballooning over time
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# Fetch current AWS account ID — needed to build the registry URL
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
