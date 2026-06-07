data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── OIDC Provider ────────────────────────────────────────────────────────────
# Tells AWS to trust GitHub's identity tokens
# GitHub Actions sends a short-lived JWT; AWS validates it against this provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]

  # GitHub's OIDC certificate thumbprint
  # AWS now validates against its own CA store, but the field is still required
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ─── IAM Role — assumed by GitHub Actions ─────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "${var.cluster_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          # Only THIS repo can assume this role
          # repo:owner/name:* means any branch/PR in the repo
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# ─── Policy: ECR push access ──────────────────────────────────────────────────
resource "aws_iam_policy" "ecr_push" {
  name        = "${var.cluster_name}-ecr-push-policy"
  description = "Allows GitHub Actions to push images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken is account-level — no resource restriction possible
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Scope push/pull to only our ECR repos
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

# ─── Policy: EKS deploy access ───────────────────────────────────────────────
resource "aws_iam_policy" "eks_deploy" {
  name        = "${var.cluster_name}-eks-deploy-policy"
  description = "Allows GitHub Actions to update kubeconfig and deploy to EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EKSDescribe"
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

resource "aws_iam_role_policy_attachment" "eks_deploy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.eks_deploy.arn
}

# ─── Policy: Terraform state access (for infra workflow) ─────────────────────
resource "aws_iam_role_policy_attachment" "terraform_infra" {
  role       = aws_iam_role.github_actions.name
  # PowerUserAccess lets the infra workflow run terraform apply
  # In production, scope this down to only resources Terraform manages
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
