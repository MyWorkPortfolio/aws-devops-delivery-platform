locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
  namespace     = "DeployTrack/${var.environment}"
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == null ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---------------------------------------------------------------------------
# Golden signals: errors, latency, saturation, plus app level errors from logs
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${var.name}-5xx-rate"
  alarm_description   = "Target 5xx rate above ${var.error_rate_threshold_percent}%. Runbook: docs/runbooks/high-error-rate.md"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.error_rate_threshold_percent
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "rate"
    expression  = "IF(requests > 0, 100 * errors / requests, 0)"
    label       = "5xx rate percent"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "latency_p95" {
  alarm_name          = "${var.name}-latency-p95"
  alarm_description   = "p95 latency above ${var.latency_p95_threshold_seconds}s. Runbook: docs/runbooks/high-latency.md"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = var.latency_p95_threshold_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name}-unhealthy-targets"
  alarm_description   = "At least one task failing readiness. Runbook: docs/runbooks/failed-deployment.md"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_saturation" {
  for_each = toset(["CPUUtilization", "MemoryUtilization"])

  alarm_name          = "${var.name}-${lower(each.key)}-high"
  alarm_description   = "${each.key} above 85% for 10 minutes even after autoscaling. Check max_count."
  namespace           = "AWS/ECS"
  metric_name         = each.key
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 10
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${var.name}-dynamodb-throttles"
  alarm_description   = "DynamoDB is throttling reads or writes."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  metric_query {
    id          = "throttles"
    expression  = "reads + writes"
    label       = "Throttle events"
    return_data = true
  }

  metric_query {
    id = "reads"
    metric {
      namespace   = "AWS/DynamoDB"
      metric_name = "ReadThrottleEvents"
      period      = 60
      stat        = "Sum"
      dimensions  = { TableName = var.dynamodb_table_name }
    }
  }

  metric_query {
    id = "writes"
    metric {
      namespace   = "AWS/DynamoDB"
      metric_name = "WriteThrottleEvents"
      period      = 60
      stat        = "Sum"
      dimensions  = { TableName = var.dynamodb_table_name }
    }
  }
}

# The app logs JSON, so CloudWatch can count ERROR lines without regex parsing.
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.name}-app-errors"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name          = "AppErrors"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${var.name}-app-errors"
  alarm_description   = "Application logged ERROR lines. Start with CloudWatch Logs Insights on ${var.log_group_name}."
  namespace           = local.namespace
  metric_name         = "AppErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.app_error_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

# ---------------------------------------------------------------------------
# One dashboard per environment, same layout everywhere
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Requests and 5xx"
          region = var.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Latency p50 / p95 / p99"
          region = var.region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50" }],
            ["...", { stat = "p95" }],
            ["...", { stat = "p99" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "ECS CPU and memory"
          region = var.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Healthy vs unhealthy tasks"
          region = var.region
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."],
          ]
        }
      },
      {
        type = "log", x = 0, y = 12, width = 24, height = 6
        properties = {
          title  = "Recent errors"
          region = var.region
          query  = "SOURCE '${var.log_group_name}' | fields @timestamp, message, request_id, route | filter level = 'ERROR' | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
    ]
  })
}
