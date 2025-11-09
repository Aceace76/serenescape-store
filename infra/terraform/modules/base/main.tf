terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  az_count     = length(local.selected_azs)
  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
  }
  sanitized_project = replace(var.project_name, "/[^a-zA-Z0-9-]/", "-")
  db_name           = substr(replace(var.project_name, "/[^a-zA-Z0-9]/", ""), 0, 30)
}

module "network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs                = local.selected_azs
  public_subnets     = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets    = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + local.az_count)]
  database_subnets   = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + (2 * local.az_count))]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  create_igw             = true
  enable_dns_support     = true
  enable_dns_hostnames   = true
  create_database_subnet_group = true

  public_subnet_tags = {
    Tier = "public"
  }

  private_subnet_tags = {
    Tier = "private"
  }

  database_subnet_tags = {
    Tier = "database"
  }

  tags = local.tags
}

resource "random_string" "bucket_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "aws_s3_bucket" "assets" {
  bucket = "${local.sanitized_project}-assets-${random_string.bucket_suffix.result}"

  tags = merge(local.tags, { Name = "${var.project_name}-assets" })
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "workflows" {
  name                 = "${var.project_name}-workflows"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.tags, { Name = "${var.project_name}-workflows" })
}

resource "aws_security_group" "compute" {
  name        = "${var.project_name}-compute"
  description = "Allow egress for compute tasks"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-compute" })
}

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database"
  description = "Allow PostgreSQL traffic from compute resources"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.compute.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-database" })
}

module "database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.5.4"

  identifier = "${local.sanitized_project}-postgres"

  engine            = "postgres"
  engine_version    = var.database.engine_version
  family            = "postgres${replace(var.database.engine_version, ".", "")}"
  major_engine_version = split(".", var.database.engine_version)[0]

  instance_class = var.database.instance_class
  allocated_storage = var.database.allocated_storage_gb
  max_allocated_storage = var.database.allocated_storage_gb + 100

  db_name  = local.db_name != "" ? local.db_name : "appdb"
  username = var.database.username
  password = var.database.password

  multi_az               = true
  storage_encrypted      = true
  backup_retention_period = var.database.backup_retention_days
  deletion_protection    = true

  publicly_accessible = false

  vpc_security_group_ids = [aws_security_group.database.id]
  create_db_subnet_group = false
  subnet_ids             = module.network.database_subnets
  db_subnet_group_name   = module.network.database_subnet_group_name

  manage_master_user_password = false

  tags = local.tags
}

resource "aws_iam_role" "workflow_engine" {
  name               = "${var.project_name}-workflow-engine"
  assume_role_policy = data.aws_iam_policy_document.workflow_assume_role.json

  tags = merge(local.tags, { Name = "${var.project_name}-workflow-engine" })
}

data "aws_iam_policy_document" "workflow_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

data "aws_iam_policy_document" "workflow_permissions" {
  statement {
    actions = [
      "lambda:InvokeFunction",
      "ecs:RunTask",
      "events:PutTargets",
      "events:PutRule",
      "events:DescribeRule",
      "sqs:SendMessage",
      "sns:Publish",
      "s3:GetObject",
      "s3:PutObject",
      "states:StartExecution",
      "iam:PassRole"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "workflow_policy" {
  name   = "${var.project_name}-workflow-policy"
  role   = aws_iam_role.workflow_engine.id
  policy = data.aws_iam_policy_document.workflow_permissions.json
}

resource "aws_sfn_state_machine" "content_pipeline" {
  count = var.enable_step_functions ? 1 : 0

  name     = "${var.project_name}-content-pipeline"
  role_arn = aws_iam_role.workflow_engine.arn

  definition = jsonencode({
    Comment = "Starter state machine for AI video pipeline"
    StartAt = "Placeholder"
    States = {
      Placeholder = {
        Type    = "Pass"
        Result  = "Replace this definition with the real workflow"
        End     = true
      }
    }
  })
}
