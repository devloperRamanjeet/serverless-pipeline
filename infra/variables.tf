variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
variable "enable_alarms" {
  description = "Enable CloudWatch alarms and SNS notifications"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard creation"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring (1-minute metrics)"
  type        = bool
  default     = false
}