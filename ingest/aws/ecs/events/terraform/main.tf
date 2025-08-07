# ==============================================================================
# Local values and data sources
# ==============================================================================

locals {
  has_basic_auth = var.firetiger_username != "" && var.firetiger_password != ""
  create_dead_letter_queue = var.enable_dead_letter_queue
  
  tags = {
    ManagedBy = "Terraform"
    Project   = "Firetiger"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==============================================================================
# Dead Letter Queue for failed events (optional)
# ==============================================================================

resource "aws_sqs_queue" "event_dead_letter_queue" {
  count = local.create_dead_letter_queue ? 1 : 0
  
  name                       = "${var.name_prefix}-eventbridge-ecs-dlq"
  message_retention_seconds  = var.dead_letter_queue_retention_seconds
  visibility_timeout_seconds = 60

  tags = local.tags
}

# ==============================================================================
# EventBridge Connection for authentication to Firetiger endpoint
# ==============================================================================

resource "aws_cloudwatch_event_connection" "firetiger_connection" {
  name        = "${var.name_prefix}-firetiger-connection"
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
  name                             = "${var.name_prefix}-firetiger-destination"
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
  name = "${var.name_prefix}-eventbridge-role"

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
  name = "EventBridgeApiDestinationPolicy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "events:InvokeApiDestination"
        ]
        Resource = aws_cloudwatch_event_api_destination.firetiger_api_destination.arn
      }
    ], local.create_dead_letter_queue ? [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.event_dead_letter_queue[0].arn
      }
    ] : [])
  })
}

# ==============================================================================
# EventBridge Rule to capture ECS Task State Changes with configurable pattern
# ==============================================================================

resource "aws_cloudwatch_event_rule" "ecs_task_state_change_rule" {
  name           = var.event_bridge_rule_name
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

  dynamic "dead_letter_config" {
    for_each = local.create_dead_letter_queue ? [1] : []
    content {
      arn = aws_sqs_queue.event_dead_letter_queue[0].arn
    }
  }
}

# ==============================================================================
# CloudWatch Log Group for monitoring EventBridge rule metrics
# ==============================================================================

resource "aws_cloudwatch_log_group" "eventbridge_log_group" {
  name              = "/aws/events/rule/${var.name_prefix}-${var.event_bridge_rule_name}"
  retention_in_days = 7

  tags = local.tags
}