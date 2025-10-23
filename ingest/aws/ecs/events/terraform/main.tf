# ==============================================================================
# Local values and data sources
# ==============================================================================

locals {
  has_basic_auth = var.firetiger_username != "" && var.firetiger_password != ""

  tags = {
    ManagedBy = "Terraform"
    Project   = "Firetiger"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==============================================================================
# EventBridge Connection for authentication to Firetiger endpoint
# ==============================================================================

resource "aws_cloudwatch_event_connection" "firetiger_connection" {
  name        = "${var.name_prefix}-ecs-task-state-conn"
  description = "Connection to Firetiger ingest server for ECS events"

  authorization_type = local.has_basic_auth ? "BASIC" : "API_KEY"

  auth_parameters {
    dynamic "basic" {
      for_each = local.has_basic_auth ? [1] : []
      content {
        username = var.firetiger_username
        password = var.firetiger_password
      }
    }

    dynamic "api_key" {
      for_each = local.has_basic_auth ? [] : [1]
      content {
        key   = "Authorization"
        value = "Bearer none"
      }
    }
  }
}

# ==============================================================================
# EventBridge API Destination pointing to Firetiger ingest server
# ==============================================================================

resource "aws_cloudwatch_event_api_destination" "firetiger_api_destination" {
  name                             = "${var.name_prefix}-ecs-task-state-dest"
  description                      = "Firetiger ingest server endpoint for ECS events"
  invocation_endpoint              = "${var.firetiger_endpoint}/aws/eventbridge/ecs-task-state-change"
  http_method                      = "POST"
  invocation_rate_limit_per_second = var.invocation_rate_per_second
  connection_arn                   = aws_cloudwatch_event_connection.firetiger_connection.arn
}

# ==============================================================================
# IAM Role for EventBridge to invoke the API destination and SQS
# ==============================================================================

resource "aws_iam_role" "eventbridge_role" {
  name = "${var.name_prefix}-ecs-task-state-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "eventbridge_api_destination_policy" {
  name = "${var.name_prefix}-ecs-task-state-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:InvokeApiDestination"
        ]
        Resource = aws_cloudwatch_event_api_destination.firetiger_api_destination.arn
      }
    ]
  })
}

# ==============================================================================
# EventBridge Rule to capture ECS Task State Changes with configurable pattern
# ==============================================================================

resource "aws_cloudwatch_event_rule" "ecs_task_state_change_rule" {
  name           = "${var.name_prefix}-${var.event_bridge_rule_name}"
  description    = "Capture ECS task state change events and send to Firetiger"
  event_bus_name = var.event_bridge_bus
  state          = "ENABLED"
  event_pattern  = var.event_pattern

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "firetiger_api_destination_target" {
  rule           = aws_cloudwatch_event_rule.ecs_task_state_change_rule.name
  event_bus_name = var.event_bridge_bus
  target_id      = "FiretigerApiDestination"
  arn            = aws_cloudwatch_event_api_destination.firetiger_api_destination.arn
  role_arn       = aws_iam_role.eventbridge_role.arn

  retry_policy {
    maximum_retry_attempts       = 0
    maximum_event_age_in_seconds = 3600
  }
}
