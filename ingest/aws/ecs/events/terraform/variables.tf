variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "firetiger-eventbridge-ecs"
}

variable "firetiger_endpoint" {
  type        = string
  description = "Firetiger ingest server endpoint (e.g., https://ingest.my-deployment.firetigerapi.com)"
}

variable "firetiger_username" {
  type        = string
  description = "Username for basic authentication to Firetiger ingest server"
  default     = ""
}

variable "firetiger_password" {
  type        = string
  description = "Password for basic authentication to Firetiger ingest server"
  default     = ""
  sensitive   = true
}

variable "event_bridge_rule_name" {
  type        = string
  description = "Name for the EventBridge rule"
  default     = "firetiger-ecs-task-state-change"
}

variable "event_pattern" {
  type        = string
  description = "EventBridge rule pattern to match ECS task state change events (JSON string)"
  default     = jsonencode({
    source        = ["aws.ecs"]
    detail-type   = ["ECS Task State Change"]
    detail = {
      lastStatus    = ["STOPPED"]
      stoppedReason = [
        { prefix = "OutOfMemoryError" },
        { prefix = "OutOfMemory" }
      ]
    }
  })
}

variable "invocation_rate_per_second" {
  type        = number
  description = "Maximum number of invocations per second for the API destination"
  default     = 1
  
  validation {
    condition     = var.invocation_rate_per_second >= 1 && var.invocation_rate_per_second <= 300
    error_message = "Invocation rate per second must be between 1 and 300."
  }
}

variable "enable_dead_letter_queue" {
  type        = bool
  description = "Enable dead letter queue for failed events"
  default     = true
}

variable "dead_letter_queue_retention_seconds" {
  type        = number
  description = "Dead letter queue message retention period in seconds"
  default     = 86400  # 1 day
  
  validation {
    condition     = var.dead_letter_queue_retention_seconds >= 60 && var.dead_letter_queue_retention_seconds <= 1209600
    error_message = "Dead letter queue retention must be between 60 seconds (1 minute) and 1209600 seconds (14 days)."
  }
}

variable "event_bridge_bus" {
  type        = string
  description = "EventBridge bus to use (default or custom bus name)"
  default     = "default"
}