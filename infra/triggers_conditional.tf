# Configuration-driven trigger setup
# This file reads the trigger configuration and creates the necessary AWS resources

locals {
  # Load trigger configuration
  config_path = "${path.module}/../config/triggers.yaml"
}

# Parse YAML configuration (using local values as workaround)
# In production, use Terraform Cloud or convert to HCL/JSON first
locals {
  function_config = {
    name        = "ray-converter"
    runtime     = "python3.11"
    timeout     = 30
    memory_size = 128
  }

  # Triggers configuration (parsed from config/triggers.yaml)
  triggers = {
    api_gateway = {
      enabled             = true
      route               = "POST /ray"
      cors_enabled        = true
      allow_origins       = ["*"]
      allow_methods       = ["GET", "POST", "PUT", "DELETE"]
      allow_headers       = ["Content-Type", "Authorization"]
    }
    sqs = {
      enabled      = false
      queue_name   = "ray-converter-queue"
      batch_size   = 10
      batch_window = 5
    }
    s3 = {
      enabled      = false
      bucket_name  = "ray-converter-input"
      events       = ["s3:ObjectCreated:*"]
      key_prefix   = "input/"
      key_suffix   = ".json"
    }
    eventbridge = {
      enabled  = false
      schedule = "rate(1 hour)"
    }
    dynamodb = {
      enabled            = false
      table_name         = "ray-events"
      stream_view_type   = "NEW_AND_OLD_IMAGES"
      batch_size         = 100
    }
    sns = {
      enabled     = false
      topic_name  = "ray-conversion-topic"
    }
  }
}

# ============================================
# API GATEWAY TRIGGER (CONDITIONAL)
# ============================================

resource "aws_apigatewayv2_api" "http_api" {
  count         = local.triggers.api_gateway.enabled ? 1 : 0
  name          = "${local.function_config.name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = local.triggers.api_gateway.allow_origins
    allow_methods = local.triggers.api_gateway.allow_methods
    allow_headers = local.triggers.api_gateway.allow_headers
  }
}

resource "aws_apigatewayv2_integration" "ray_converter_integration" {
  count              = local.triggers.api_gateway.enabled ? 1 : 0
  api_id             = aws_apigatewayv2_api.http_api[0].id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"

  target = aws_lambda_function.ray_converter.arn
}

resource "aws_apigatewayv2_route" "ray_converter_route" {
  count     = local.triggers.api_gateway.enabled ? 1 : 0
  api_id    = aws_apigatewayv2_api.http_api[0].id
  route_key = local.triggers.api_gateway.route
  target    = "integrations/${aws_apigatewayv2_integration.ray_converter_integration[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  count            = local.triggers.api_gateway.enabled ? 1 : 0
  api_id           = aws_apigatewayv2_api.http_api[0].id
  name             = "$default"
  auto_deploy      = true

  default_route_settings {
    logging_level            = "INFO"
    data_trace_enabled       = true
    detailed_metrics_enabled = true
  }
}

resource "aws_lambda_permission" "api_gateway" {
  count         = local.triggers.api_gateway.enabled ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ray_converter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api[0].execution_arn}/*/*"
}

# ============================================
# SQS TRIGGER (CONDITIONAL)
# ============================================

resource "aws_sqs_queue" "ray_converter_queue" {
  count                     = local.triggers.sqs.enabled ? 1 : 0
  name                      = local.triggers.sqs.queue_name
  message_retention_seconds = 1209600  # 14 days
}

resource "aws_lambda_event_source_mapping" "sqs" {
  count            = local.triggers.sqs.enabled ? 1 : 0
  event_source_arn = aws_sqs_queue.ray_converter_queue[0].arn
  function_name    = aws_lambda_function.ray_converter.arn
  batch_size       = local.triggers.sqs.batch_size
  batch_window     = local.triggers.sqs.batch_window
}

resource "aws_lambda_permission" "sqs" {
  count         = local.triggers.sqs.enabled ? 1 : 0
  statement_id  = "AllowSQSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ray_converter.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.ray_converter_queue[0].arn
}

# ============================================
# S3 TRIGGER (CONDITIONAL)
# ============================================

resource "aws_s3_bucket" "ray_converter_bucket" {
  count  = local.triggers.s3.enabled ? 1 : 0
  bucket = local.triggers.s3.bucket_name
}

resource "aws_s3_bucket_notification" "ray_converter_notification" {
  count      = local.triggers.s3.enabled ? 1 : 0
  bucket     = aws_s3_bucket.ray_converter_bucket[0].id
  depends_on = [aws_lambda_permission.s3]

  lambda_function {
    lambda_function_arn = aws_lambda_function.ray_converter.arn
    events              = local.triggers.s3.events
    filter_prefix       = local.triggers.s3.key_prefix
    filter_suffix       = local.triggers.s3.key_suffix
  }
}

resource "aws_lambda_permission" "s3" {
  count         = local.triggers.s3.enabled ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ray_converter.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${local.triggers.s3.bucket_name}"
}

# ============================================
# EVENTBRIDGE TRIGGER (CONDITIONAL)
# ============================================

resource "aws_cloudwatch_event_rule" "schedule" {
  count               = local.triggers.eventbridge.enabled ? 1 : 0
  name                = "${local.function_config.name}-schedule"
  schedule_expression = local.triggers.eventbridge.schedule
  is_enabled          = true
}

resource "aws_cloudwatch_event_target" "lambda" {
  count      = local.triggers.eventbridge.enabled ? 1 : 0
  rule       = aws_cloudwatch_event_rule.schedule[0].name
  target_id  = "RayConverterLambda"
  arn        = aws_lambda_function.ray_converter.arn

  input = jsonencode({
    ray = { source = "eventbridge" }
  })
}

resource "aws_lambda_permission" "eventbridge" {
  count         = local.triggers.eventbridge.enabled ? 1 : 0
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ray_converter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}

# ============================================
# OUTPUTS
# ============================================

output "enabled_triggers" {
  value = [
    for trigger_type, config in local.triggers :
    trigger_type if config.enabled
  ]
  description = "List of enabled trigger types"
}

output "api_gateway_endpoint" {
  value       = try(aws_apigatewayv2_stage.default[0].invoke_url, null)
  description = "API Gateway endpoint URL (if enabled)"
}

output "sqs_queue_url" {
  value       = try(aws_sqs_queue.ray_converter_queue[0].url, null)
  description = "SQS Queue URL (if enabled)"
}

output "s3_bucket_name" {
  value       = try(aws_s3_bucket.ray_converter_bucket[0].id, null)
  description = "S3 Bucket name (if enabled)"
}

output "eventbridge_rule" {
  value       = try(aws_cloudwatch_event_rule.schedule[0].name, null)
  description = "EventBridge rule name (if enabled)"
}