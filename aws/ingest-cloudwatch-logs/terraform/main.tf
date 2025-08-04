# ==============================================================================
# Local values and data sources
# ==============================================================================

locals {
  has_basic_auth = var.firetiger_username != "" && var.firetiger_password != ""
  
  lambda_function_name = "${var.name_prefix}-cloudwatch-logs-ingester"
  subscription_filter_manager_name = "${var.name_prefix}-subscription-filter-manager"
  
  tags = {
    ManagedBy = "Terraform"
    Project   = "Firetiger"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  tags = local.tags
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
  role         = aws_iam_role.lambda_execution_role.arn
  runtime      = "python3.13"
  handler      = "index.lambda_handler"
  timeout      = var.lambda_timeout
  memory_size  = var.lambda_memory_size
  architectures = ["x86_64"]

  s3_bucket         = "firetiger-public"
  s3_key            = "aws/ingest-cloudwatch-logs/lambda/ingester.zip"
  source_code_hash  = data.aws_s3_object.lambda_code.etag

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
  bucket = "firetiger-public"
  key    = "aws/ingest-cloudwatch-logs/lambda/ingester.zip"
}

# ==============================================================================
# Permission for CloudWatch Logs to invoke Lambda
# ==============================================================================

resource "aws_lambda_permission" "cloudwatch_logs_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_logs_ingester.function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# ==============================================================================
# IAM Role for Subscription Filter Manager
# ==============================================================================

resource "aws_iam_role" "subscription_filter_manager_role" {
  name = "${var.name_prefix}-subscription-filter-manager-role"

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

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  inline_policy {
    name = "CloudWatchLogsAccess"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:DescribeLogGroups",
            "logs:PutSubscriptionFilter",
            "logs:DeleteSubscriptionFilter",
            "logs:DescribeSubscriptionFilters"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = local.tags
}

# ==============================================================================
# Lambda function to manage subscription filters
# ==============================================================================

resource "aws_lambda_function" "subscription_filter_manager" {
  function_name = local.subscription_filter_manager_name
  role         = aws_iam_role.subscription_filter_manager_role.arn
  runtime      = "python3.13"
  handler      = "index.lambda_handler"
  timeout      = 300

  s3_bucket         = "firetiger-public"
  s3_key            = "aws/ingest-cloudwatch-logs/lambda/filter_manager.zip"
  source_code_hash  = data.aws_s3_object.filter_manager_code.etag

  tags = local.tags
}

# Reference Filter Manager Lambda deployment package from S3
data "aws_s3_object" "filter_manager_code" {
  bucket = "firetiger-public"
  key    = "aws/ingest-cloudwatch-logs/lambda/filter_manager.zip"
}

# ==============================================================================
# Custom Resource to create subscription filters for matching log groups
# ==============================================================================

resource "aws_cloudformation_stack" "subscription_filter_manager" {
  name = "${var.name_prefix}-subscription-filters"
  
  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Resources = {
      SubscriptionFilterManager = {
        Type = "AWS::CloudFormation::CustomResource"
        Properties = {
          ServiceToken = aws_lambda_function.subscription_filter_manager.arn
          LambdaArn = aws_lambda_function.cloudwatch_logs_ingester.arn
          FilterPattern = var.subscription_filter_pattern
          LogGroupPatterns = var.log_group_patterns
          StackName = var.name_prefix
        }
      }
    }
    Outputs = {
      FilterCount = {
        Value = { "Fn::GetAtt" = ["SubscriptionFilterManager", "FilterCount"] }
      }
      MonitoredLogGroups = {
        Value = { "Fn::GetAtt" = ["SubscriptionFilterManager", "MonitoredLogGroups"] }
      }
    }
  })
  
  tags = local.tags
}