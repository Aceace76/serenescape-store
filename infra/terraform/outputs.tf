output "network" {
  description = "Core networking identifiers."
  value = {
    vpc_id              = module.base.vpc_id
    public_subnet_ids   = module.base.public_subnet_ids
    private_subnet_ids  = module.base.private_subnet_ids
  }
}

output "storage" {
  description = "Asset storage resources."
  value = {
    asset_bucket_name = module.base.asset_bucket_name
    ecr_repository_url = module.base.ecr_repository_url
  }
}

output "database" {
  description = "Database connection details."
  value = {
    endpoint           = module.base.database_endpoint
    port               = module.base.database_port
    db_name            = module.base.database_name
    secret_arn         = module.base.database_secret_arn
  }
  sensitive = true
}

output "orchestration" {
  description = "Step Functions orchestration artifacts."
  value = module.base.orchestration
}
