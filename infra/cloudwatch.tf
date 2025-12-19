# CloudWatch Monitoring and Alarms for Ray Converter Lambda

# ============================================================
# CLOUDWATCH LOG GROUP - Already defined in main.tf
# Retention: 14 days (can be increased to 30/90 for production)
# ============================================================

# Log Group is created in main.tf:
# resource "aws_cloudwatch_log_group" "ray_converter_logs" {
#   name              = "/aws/lambda/ray-converter"
#   retention_in_days = 14
# }

# ============================================================
# CLOUDWATCH METRIC FILTERS - Parse logs and create metrics
# ============================================================

# Metric Filter: Count ERROR logs
resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "ray-converter-errors"
  log_group_name = aws_cloudwatch_log_group.ray_converter_logs.name
  filter_pattern = "[ERROR]"

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "RayConverter"
    value         = "1"
    default_value = 0
  }
}

# Metric Filter: Count WARNING logs
resource "aws_cloudwatch_log_metric_filter" "warning_logs" {
  name           = "ray-converter-warnings"
  log_group_name = aws_cloudwatch_log_group.ray_converter_logs.name
  filter_pattern = "[WARN]"

  metric_transformation {
    name          = "WarningCount"
    namespace     = "RayConverter"
    value         = "1"
    default_value = 0
  }
}

# Metric Filter: Count successful conversions (INFO logs with "Converted data")
resource "aws_cloudwatch_log_metric_filter" "successful_conversions" {
  name           = "ray-converter-success"
  log_group_name = aws_cloudwatch_log_group.ray_converter_logs.name
  filter_pattern = "[INFO, request_id, msg1, msg2, msg3 = \"Converted\", ...]"

  metric_transformation {
    name          = "SuccessfulConversions"
    namespace     = "RayConverter"
    value         = "1"
    default_value = 0
  }
}

# ============================================================
# CLOUDWATCH ALARMS - Alert on anomalies
# ============================================================

# ALARM 1: High Error Rate (>5 errors in 5 minutes)
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "ray-converter-high-error-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "RayConverter"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when error count exceeds 5 in 5 minutes"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.enable_alarms ? [aws_sns_topic.lambda_alerts[0].arn] : []
}

# ALARM 2: Lambda Duration Spike (>10 seconds average)
resource "aws_cloudwatch_metric_alarm" "high_duration" {
  alarm_name          = "ray-converter-high-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000"  # 10 seconds in milliseconds
  alarm_description   = "Alert when Lambda execution duration exceeds 10 seconds"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ray_converter.function_name
  }

  alarm_actions = var.enable_alarms ? [aws_sns_topic.lambda_alerts[0].arn] : []
}

# ALARM 3: Lambda Timeout (invocations that timed out)
resource "aws_cloudwatch_metric_alarm" "lambda_timeout" {
  alarm_name          = "ray-converter-timeout"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Timeout"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when Lambda function times out"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ray_converter.function_name
  }

  alarm_actions = var.enable_alarms ? [aws_sns_topic.lambda_alerts[0].arn] : []
}

# ALARM 4: Lambda Errors (AWS native metric)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "ray-converter-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Alert when Lambda function errors exceed 3 in 5 minutes"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ray_converter.function_name
  }

  alarm_actions = var.enable_alarms ? [aws_sns_topic.lambda_alerts[0].arn] : []
}

# ALARM 5: Lambda Throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "ray-converter-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when Lambda function is throttled"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.ray_converter.function_name
  }

  alarm_actions = var.enable_alarms ? [aws_sns_topic.lambda_alerts[0].arn] : []
}

# ============================================================
# SNS TOPIC FOR ALERTS - Optional email notifications
# ============================================================

resource "aws_sns_topic" "lambda_alerts" {
  count = var.enable_alarms ? 1 : 0
  name  = "ray-converter-lambda-alerts"
}

resource "aws_sns_topic_subscription" "lambda_alerts_email" {
  count     = var.enable_alarms && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.lambda_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# CLOUDWATCH DASHBOARD - Visual monitoring
# ============================================================

resource "aws_cloudwatch_dashboard" "ray_converter_dashboard" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "ray-converter-metrics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Total Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Errors" }],
            [".", "Duration", { stat = "Average", label = "Avg Duration (ms)" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Performance Metrics"
          dimensions = {
            FunctionName = aws_lambda_function.ray_converter.function_name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["RayConverter", "ErrorCount", { stat = "Sum", label = "Errors" }],
            [".", "WarningCount", { stat = "Sum", label = "Warnings" }],
            [".", "SuccessfulConversions", { stat = "Sum", label = "Successful" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Application Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "fields @timestamp, @message | filter @message like /ERROR/ | stats count() by bin(5m)"
          region  = var.aws_region
          title   = "Error Logs (Last 24h)"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", { stat = "Maximum", label = "Max Concurrent" }],
            [".", "UnreservedConcurrentExecutions", { stat = "Maximum", label = "Unreserved" }]
          ]
          period = 300
          stat   = "Maximum"
          region = var.aws_region
          title  = "Concurrency Metrics"
        }
      }
    ]
  })
}

# ============================================================
# CLOUDWATCH LOG INSIGHTS QUERIES - For debugging
# ============================================================

# Save these query snippets for manual use in CloudWatch Logs Insights

# Query 1: Find all errors in last hour
# fields @timestamp, @message
# | filter @message like /ERROR/
# | stats count() as error_count by @message

# Query 2: Analyze response times
# fields @duration
# | filter @duration > 0
# | stats avg(@duration), max(@duration), pct(@duration, 99) as p99

# Query 3: Track conversion success rate
# fields @message
# | filter @message like /Converted|Error/
# | stats count(*) as total, sum(ispresent(@message, /Converted/)) as successful
# | fields total, successful, round((successful / total) * 100) as success_rate_percent

# Query 4: Find slow requests
# fields @timestamp, @duration, @message
# | filter @duration > 5000
# | sort @duration desc
# | limit 20

# Query 5: Get errors by hour
# fields @timestamp, @message
# | filter @message like /ERROR/
# | stats count() as error_count by bin(1h)

# ============================================================
# OUTPUTS
# ============================================================

output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.ray_converter_logs.name
  description = "CloudWatch Log Group name for Lambda function"
}

output "cloudwatch_log_group_arn" {
  value       = aws_cloudwatch_log_group.ray_converter_logs.arn
  description = "CloudWatch Log Group ARN"
}

output "error_metric_filter_name" {
  value       = aws_cloudwatch_log_metric_filter.error_logs.name
  description = "Metric filter for errors"
}

output "dashboard_url" {
  value       = var.enable_dashboard ? "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=ray-converter-metrics" : null
  description = "CloudWatch Dashboard URL"
}

output "log_insights_queries" {
  value = {
    all_errors               = "fields @timestamp, @message | filter @message like /ERROR/ | stats count() as error_count by @message"
    response_times           = "fields @duration | filter @duration > 0 | stats avg(@duration), max(@duration), pct(@duration, 99) as p99"
    conversion_success_rate  = "fields @message | filter @message like /Converted|Error/ | stats count(*) as total, sum(ispresent(@message, /Converted/)) as successful"
    slow_requests            = "fields @timestamp, @duration, @message | filter @duration > 5000 | sort @duration desc"
    errors_by_hour           = "fields @timestamp, @message | filter @message like /ERROR/ | stats count() as error_count by bin(1h)"
  }
  description = "CloudWatch Logs Insights query templates"
}
