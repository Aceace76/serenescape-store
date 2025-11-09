# AWS Bootstrap Terraform

This stack bootstraps the core AWS footprint for the AI video automation platform:

- VPC with public/private/database subnets, NAT gateway, and tagging
- Private PostgreSQL (RDS) cluster with high availability
- S3 bucket for media assets (versioned, encrypted, non-public)
- ECR repository to store container images for workers
- Step Functions state machine stub and IAM role for workflow orchestration

## Prerequisites

1. **AWS account & IAM**  
   - Create an AWS account (or choose an existing one).  
   - Create an IAM user/role with `AdministratorAccess` (you can tighten later).  
   - Generate access keys for Terraform usage.

2. **Local tooling**  
   - [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) v1.6+  
   - AWS CLI (`aws configure`) for profile setup (optional but recommended).

3. **State backend**  
   - This template uses the local Terraform state file.  
   - For teams, create an S3 bucket + DynamoDB table for remote state and update `terraform` block accordingly.

## How to Deploy

```bash
cd infra/terraform

# Optional: create a TF variable file with secrets
cat <<'EOF' > terraform.tfvars
project_name    = "ai-video"
aws_region      = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]

database = {
  username              = "appuser"
  password              = "REPLACE_ME_WITH_STRONG_PASSWORD"
  allocated_storage_gb  = 20
  engine_version        = "15.5"
  instance_class        = "db.t4g.small"
  backup_retention_days = 7
}
EOF

terraform init
terraform plan
terraform apply
```

### Outputs

- `network.*` — VPC and subnet IDs for compute workloads (ECS, EKS, Lambda).  
- `storage.asset_bucket_name` — private S3 bucket ready for scripts, audio, renders.  
- `storage.ecr_repository_url` — push workers here (`docker push`).  
- `database.*` — connection details (endpoint/port/name) plus Secrets Manager ARN if enabled.  
- `orchestration.*` — Step Functions state machine ARN and IAM role.

## Next Steps

1. Create ECS/Fargate task definitions or Lambda functions for ingestion, script writing, rendering, and uploads.  
2. Replace the placeholder Step Functions definition with the real workflow JSON.  
3. Wire platform credentials (YouTube, TikTok, Meta, etc.) into Secrets Manager.  
4. Add monitoring/alerts (CloudWatch dashboards, alarms, log subscriptions).  
5. Harden security: tighten IAM policies, configure VPC endpoints, enable RDS IAM auth or Secrets Manager rotation.  
6. Add CI pipeline (e.g., GitHub Actions) to run `terraform fmt` + `terraform plan` before deploys.
