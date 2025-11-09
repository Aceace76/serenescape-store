output "vpc_id" {
  value       = module.network.vpc_id
  description = "ID of the created VPC."
}

output "public_subnet_ids" {
  value       = module.network.public_subnets
  description = "Public subnet IDs."
}

output "private_subnet_ids" {
  value       = module.network.private_subnets
  description = "Private subnet IDs."
}

output "asset_bucket_name" {
  value       = aws_s3_bucket.assets.bucket
  description = "S3 bucket for video assets."
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.workflows.repository_url
  description = "ECR repository URL for workflow images."
}

output "database_endpoint" {
  value       = module.database.db_instance_endpoint
  description = "PostgreSQL endpoint."
}

output "database_port" {
  value       = module.database.db_instance_port
  description = "PostgreSQL port."
}

output "database_name" {
  value       = module.database.db_instance_name
  description = "Database name."
}

output "database_secret_arn" {
  value       = module.database.db_instance_master_user_secret_arn
  description = "ARN of the managed secret (if enabled)."
}

output "orchestration" {
  value = {
    state_machine_arn = try(aws_sfn_state_machine.content_pipeline[0].arn, null)
    workflow_role_arn = aws_iam_role.workflow_engine.arn
  }
  description = "State machine and IAM role metadata."
}
