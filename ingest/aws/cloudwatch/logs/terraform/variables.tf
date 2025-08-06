variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "firetiger-cloudwatch-logs"
}

variable "firetiger_endpoint" {
  type        = string
  description = "Firetiger OpenTelemetry logs endpoint (e.g., https://ingest.my-deployment.firetigerapi.com)"
}

variable "firetiger_username" {
  type        = string
  description = "Username for basic authentication to Firetiger exporter"
  default     = ""
}

variable "firetiger_password" {
  type        = string
  description = "Password for basic authentication to Firetiger exporter"
  default     = ""
  sensitive   = true
}

variable "log_group_patterns" {
  type        = list(string)
  description = "List of log group name patterns to monitor (use '*' for all)"
  default     = ["*"]
}

variable "subscription_filter_pattern" {
  type        = string
  description = "CloudWatch Logs filter pattern (empty for all logs)"
  default     = ""
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Lambda function timeout in seconds"
  default     = 300
  
  validation {
    condition     = var.lambda_timeout_seconds >= 60 && var.lambda_timeout_seconds <= 900
    error_message = "Lambda timeout must be between 60 and 900 seconds."
  }
}

variable "lambda_memory_size_mb" {
  type        = number
  description = "Lambda function memory size in MB"
  default     = 256
  
  validation {
    condition     = var.lambda_memory_size_mb >= 128 && var.lambda_memory_size_mb <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention period for Lambda function logs"
  default     = 7
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}