module "base" {
  source = "./modules/base"

  project_name         = var.project_name
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  database             = var.database
  enable_step_functions = var.enable_step_functions
}
