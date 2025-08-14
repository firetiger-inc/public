# ==============================================================================
# Local values and data sources
# ==============================================================================

locals {
  has_basic_auth = var.firetiger_username != "" && var.firetiger_password != ""

  lambda_function_name = "${var.name_prefix}-cloudwatch-logs-ingester"

  # Construct bucket name based on current provider region
  s3_bucket = "firetiger-public-${data.aws_region.current.id}"

  tags = {
    ManagedBy = "Terraform"
    Project   = "Firetiger"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Validate that the S3 bucket exists for this region
data "aws_s3_bucket" "lambda_code_bucket" {
  bucket = local.s3_bucket
}

# ==============================================================================
# IAM Role for Lambda Execution
# ==============================================================================

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_basic" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ==============================================================================
# CloudWatch Log Group for Lambda Function
# ==============================================================================

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# ==============================================================================
# Lambda Function for CloudWatch Logs Processing
# ==============================================================================

resource "aws_lambda_function" "cloudwatch_logs_ingester" {
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.13"
  handler       = "index.lambda_handler"
  timeout       = var.lambda_timeout_seconds
  memory_size   = var.lambda_memory_size_mb
  architectures = ["x86_64"]

  s3_bucket        = data.aws_s3_bucket.lambda_code_bucket.name
  s3_key           = "ingest/aws/cloudwatch/logs/lambda/ingester.zip"
  source_code_hash = data.aws_s3_object.lambda_code.etag

  environment {
    variables = merge(
      {
        FT_EXPORTER_ENDPOINT = var.firetiger_endpoint
      },
      local.has_basic_auth ? {
        FT_EXPORTER_BASIC_AUTH_USERNAME = var.firetiger_username
        FT_EXPORTER_BASIC_AUTH_PASSWORD = var.firetiger_password
      } : {}
    )
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda_log_group.name
  }

  tags = local.tags

  depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}

# Reference Lambda deployment package from S3
data "aws_s3_object" "lambda_code" {
  bucket = local.s3_bucket
  key    = "ingest/aws/cloudwatch/logs/lambda/ingester.zip"
}

# ==============================================================================
# Permission for CloudWatch Logs to invoke Lambda
# ==============================================================================

resource "aws_lambda_permission" "cloudwatch_logs_lambda_permission" {
  statement_id   = "AllowExecutionFromCloudWatchLogs"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.cloudwatch_logs_ingester.function_name
  principal      = "logs.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# ==============================================================================
# Data sources for log group discovery and subscription filter management
# ==============================================================================

# Get all log groups in the account
data "aws_cloudwatch_log_groups" "all" {}

# Filter log groups based on patterns
locals {
  # Convert patterns to regex and filter log groups
  matching_log_groups = [
    for log_group in data.aws_cloudwatch_log_groups.all.log_group_names : log_group
    if anytrue([
      for pattern in var.log_group_patterns :
      pattern == "*" || can(regex(replace(pattern, "*", ".*"), log_group))
    ])
  ]
}

# ==============================================================================
# Subscription filters for matching log groups
# ==============================================================================

# Create subscription filters for matching log groups
resource "aws_cloudwatch_log_subscription_filter" "firetiger_filters" {
  for_each = toset(local.matching_log_groups)

  name            = "firetiger-${var.name_prefix}-${replace(replace(each.key, "/", "-"), "_", "-")}"
  log_group_name  = each.key
  filter_pattern  = var.subscription_filter_pattern
  destination_arn = aws_lambda_function.cloudwatch_logs_ingester.arn

  depends_on = [aws_lambda_permission.cloudwatch_logs_lambda_permission]
}

