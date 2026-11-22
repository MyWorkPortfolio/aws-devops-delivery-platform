module "platform" {
  source = "../../modules/platform"

  environment = "staging"
  region      = var.region
  image_tag   = var.image_tag
  app_version = var.app_version

  vpc_cidr           = "10.20.0.0/16"
  az_count           = 2
  single_nat_gateway = true

  cpu              = 256
  memory           = 512
  min_count        = 2
  max_count        = 4
  use_fargate_spot = true

  log_retention_days            = 14
  deletion_protection           = false
  latency_p95_threshold_seconds = 0.5

  certificate_arn = var.certificate_arn
  alarm_email     = var.alarm_email
}
