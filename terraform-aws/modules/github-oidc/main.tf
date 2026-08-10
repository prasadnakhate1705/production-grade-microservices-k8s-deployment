data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── OIDC Provider ────────────────────────────────────────────────────────────
# Tells AWS to trust GitHub's identity tokens: GitHub Actions sends a short-lived
# JWT and AWS validates it against this provider.
#
# Looked up as a DATA source, not created as a resource. The provider is a
# single ACCOUNT-WIDE object (one per issuer URL), so any other stack in this
# account that already registered GitHub would make a `resource` block fail with
# EntityAlreadyExists. Reading it keeps this module safe to apply alongside them.
#
# One-time prerequisite — if the account has never used GitHub OIDC, create it:
#   aws iam create-open-id-connect-provider \
#     --url https://token.actions.githubusercontent.com \
#     --client-id-list sts.amazonaws.com
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ─── IAM Role — assumed by GitHub Actions ─────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "${var.cluster_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
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
  role = aws_iam_role.github_actions.name
  # PowerUserAccess covers everything the stack builds EXCEPT IAM — see below.
  # In production, scope this down to only resources Terraform manages
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ─── Policy: IAM access for the infra workflow ────────────────────────────────
# PowerUserAccess is `NotAction: ["iam:*", "organizations:*", "account:*"]` plus a
# short allow-list (CreateServiceLinkedRole / DeleteServiceLinkedRole / ListRoles).
# It therefore grants NO iam:GetRole, iam:GetPolicy or iam:GetOpenIDConnectProvider.
#
# This stack manages four IAM roles/policies (EKS cluster role, node role, this
# CI role, and the two custom policies) and reads the GitHub OIDC provider as a
# data source. Without the permissions below, `terraform plan` in CI dies with
# AccessDenied during REFRESH — before it can compare anything — so the infra
# workflow can never reach apply.
#
# Scoped by ARN prefix to this cluster's own resources rather than iam:* — note
# this does let CI modify its own role, which is unavoidable once CI owns the
# Terraform that defines that role. The repo-scoped OIDC trust policy above is
# what keeps that bounded.
resource "aws_iam_policy" "iam_manage" {
  name        = "${var.cluster_name}-iam-manage-policy"
  description = "Scoped IAM access so the infra workflow can plan/apply this stack's roles and policies"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageThisStacksRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-*"
      },
      {
        Sid    = "ManageThisStacksPolicies"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListEntitiesForPolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.cluster_name}-*"
      },
      {
        # Read-only — the provider is a data source, never created here.
        Sid      = "ReadGitHubOIDCProvider"
        Effect   = "Allow"
        Action   = "iam:GetOpenIDConnectProvider"
        Resource = data.aws_iam_openid_connect_provider.github.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_manage" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.iam_manage.arn
}
