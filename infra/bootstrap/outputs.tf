output "state_bucket" {
  description = "Set as the TF_STATE_BUCKET repository variable."
  value       = aws_s3_bucket.state.bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "build_role_arn" {
  description = "Set as the AWS_BUILD_ROLE_ARN repository variable."
  value       = aws_iam_role.build.arn
}

output "deploy_role_arns" {
  description = "Set each as AWS_DEPLOY_ROLE_ARN on the matching GitHub Environment."
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}
