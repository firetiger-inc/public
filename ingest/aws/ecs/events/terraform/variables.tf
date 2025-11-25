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
  description = "Name for the EventBridge rule (will be prefixed with name_prefix)"
  default     = "ecs-task-state"
}

variable "event_pattern" {
  type        = string
  description = "EventBridge rule pattern to match ECS task state change events (JSON string). See AWS docs for event structure: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html"
  default     = <<-EOT
    {
      "source": ["aws.ecs"],
      "detail-type": ["ECS Task State Change"],
      "detail": {
        "lastStatus": ["STOPPED"]
      }
    }
  EOT
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

variable "event_bridge_bus" {
  type        = string
  description = "EventBridge bus to use (default or custom bus name)"
  default     = "default"
}

variable "iam_permissions_boundary_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional ARN of an IAM permissions boundary policy to attach to IAM roles."
}