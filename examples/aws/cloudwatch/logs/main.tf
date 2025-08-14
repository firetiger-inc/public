# Example Terraform configuration for deploying Firetiger CloudWatch Logs integration
# using the GitHub-hosted module

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Deploy the Firetiger CloudWatch Logs integration module
module "firetiger_cloudwatch_logs" {
  source = "github.com/firetiger-inc/public//ingest/aws/cloudwatch/logs/terraform?ref=main"

  # Naming and identification
  name_prefix = "my-company-logs"

  # Firetiger endpoint configuration
  firetiger_endpoint = "https://ingest.my-deployment.firetigerapi.com"
  firetiger_username = "my-username"
  firetiger_password = "your-password-here" # Replace with your actual password

  # Log group monitoring configuration
  log_group_patterns = [
    "/ecs/*",
    "/aws/lambda/*",
    "/aws/rds/*"
  ]

  # Optional: Filter pattern for logs (empty string means all logs)
  subscription_filter_pattern = ""

  # Lambda configuration
  lambda_timeout_seconds = 60  # 1 minute
  lambda_memory_size_mb  = 256 # MB

  # CloudWatch Logs retention for Lambda function logs
  log_retention_days = 7
}

