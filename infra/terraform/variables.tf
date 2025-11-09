variable "project_name" {
  description = "Short name used for tagging and resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "database" {
  description = "Database configuration parameters."
  type = object({
    username              = string
    password              = string
    allocated_storage_gb  = optional(number, 20)
    engine_version        = optional(string, "15.5")
    instance_class        = optional(string, "db.t4g.small")
    backup_retention_days = optional(number, 7)
  })
}

variable "vpc_cidr" {
  description = "CIDR block for the primary VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to spread resources across."
  type        = list(string)
  default     = []
}

variable "enable_step_functions" {
  description = "Whether to deploy the starter Step Functions state machine."
  type        = bool
  default     = true
}
