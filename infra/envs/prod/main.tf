module "platform" {
  source = "../../modules/platform"

  environment = "prod"
  region      = var.region
  image_tag   = var.image_tag
  app_version = var.app_version

  vpc_cidr           = "10.30.0.0/16"
  az_count           = 3
  single_nat_gateway = false

  cpu              = 512
  memory           = 1024
  min_count        = 3
  max_count        = 10
  use_fargate_spot = false

  log_retention_days            = 90
  deletion_protection           = true
  latency_p95_threshold_seconds = 0.5

  certificate_arn = var.certificate_arn
  alarm_email     = var.alarm_email
}
