# Composes the whole stack for one environment. Every environment calls this module
# with different sizing, so dev, staging and prod are structurally identical and
# only differ in the knobs listed in docs/environments.md.

locals {
  name = "${var.project}-${var.environment}"
}

data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

module "network" {
  source = "../network"

  name               = local.name
  region             = var.region
  cidr_block         = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

module "table" {
  source = "../dynamodb"

  name                = "${local.name}-deployments"
  deletion_protection = var.deletion_protection
}

module "service" {
  source = "../ecs_service"

  name               = local.name
  environment        = var.environment
  region             = var.region
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  container_image = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
  app_version     = var.app_version

  cpu              = var.cpu
  memory           = var.memory
  desired_count    = var.min_count
  min_count        = var.min_count
  max_count        = var.max_count
  use_fargate_spot = var.use_fargate_spot

  dynamodb_table_name = module.table.name
  dynamodb_table_arn  = module.table.arn

  log_retention_days         = var.log_retention_days
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = var.deletion_protection
}

module "observability" {
  source = "../observability"

  name                          = local.name
  environment                   = var.environment
  region                        = var.region
  alarm_email                   = var.alarm_email
  alb_arn_suffix                = module.service.alb_arn_suffix
  target_group_arn_suffix       = module.service.target_group_arn_suffix
  cluster_name                  = module.service.cluster_name
  service_name                  = module.service.service_name
  dynamodb_table_name           = module.table.name
  log_group_name                = module.service.log_group_name
  latency_p95_threshold_seconds = var.latency_p95_threshold_seconds
}
