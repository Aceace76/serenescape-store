variable "project_name" {
  type        = string
  description = "Project name prefix for resource naming."
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources are deployed."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block assigned to the VPC."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of AZs for subnets. Leave empty to let AWS pick automatically."
  default     = []
}

variable "database" {
  description = "Database configuration."
  type = object({
    username              = string
    password              = string
    allocated_storage_gb  = optional(number, 20)
    engine_version        = optional(string, "15.5")
    instance_class        = optional(string, "db.t4g.small")
    backup_retention_days = optional(number, 7)
  })
}

variable "enable_step_functions" {
  type        = bool
  description = "Flag to create a starter Step Functions state machine."
  default     = true
}
