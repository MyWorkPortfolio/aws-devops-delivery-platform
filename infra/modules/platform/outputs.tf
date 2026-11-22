output "service_url" {
  value = module.service.url
}

output "cluster_name" {
  value = module.service.cluster_name
}

output "service_name" {
  value = module.service.service_name
}

output "dashboard_name" {
  value = module.observability.dashboard_name
}

output "alerts_topic_arn" {
  value = module.observability.alerts_topic_arn
}
