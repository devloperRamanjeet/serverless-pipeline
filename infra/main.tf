terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "ray-converter-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function for ray_converter
resource "aws_lambda_function" "ray_converter" {
  filename      = data.archive_file.ray_converter_zip.output_path
  function_name = "ray-converter"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 128

  source_code_hash = data.archive_file.ray_converter_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Archive the Lambda function code
data "archive_file" "ray_converter_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/ray_converter"
  output_path = "${path.module}/../build/ray_converter.zip"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "ray_converter_logs" {
  name              = "/aws/lambda/ray-converter"
  retention_in_days = var.log_retention_days
}

output "lambda_function_arn" {
  value       = aws_lambda_function.ray_converter.arn
  description = "ARN of the ray_converter Lambda function"
}

output "lambda_function_name" {
  value       = aws_lambda_function.ray_converter.function_name
  description = "Name of the ray_converter Lambda function"
}
