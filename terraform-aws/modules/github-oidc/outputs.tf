output "role_arn" {
  description = "ARN of the IAM role — add this to GitHub Secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
