module "platform" {
  source = "../../modules/platform"

  environment = "dev"
  region      = var.region
  image_tag   = var.image_tag
  app_version = var.app_version

  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  single_nat_gateway = true

  cpu              = 256
  memory           = 512
  min_count        = 1
  max_count        = 2
  use_fargate_spot = true

  log_retention_days            = 7
  deletion_protection           = false
  latency_p95_threshold_seconds = 1.0

  certificate_arn = var.certificate_arn
  alarm_email     = var.alarm_email
}
