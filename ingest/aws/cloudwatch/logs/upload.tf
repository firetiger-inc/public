# ==============================================================================
# Upload Lambda packages to S3
# 
# This configuration uploads the Lambda deployment packages to the 
# firetiger-public S3 bucket for use by both CloudFormation and Terraform.
# ==============================================================================

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "firetiger-terraform"
    key    = "public/ingest/aws/cloudwatch/logs/terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

data "aws_s3_bucket" "firetiger_public" {
  bucket = "firetiger-public"
}

# Create Lambda deployment packages locally
data "archive_file" "ingester" {
  type        = "zip"
  output_path = "${path.module}/build/ingester.zip"
  source {
    content  = file("${path.module}/src/ingester.py")
    filename = "index.py"
  }
}

data "archive_file" "filter_manager" {
  type        = "zip"
  output_path = "${path.module}/build/filter_manager.zip"
  source {
    content  = file("${path.module}/src/filter_manager.py")
    filename = "index.py"
  }
}

# Upload Ingester Lambda package to S3
resource "aws_s3_object" "ingester_lambda" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/cloudwatch/logs/lambda/ingester.zip"
  source = data.archive_file.ingester.output_path

  content_type = "application/zip"
  etag         = data.archive_file.ingester.output_md5

  metadata = {
    description = "Firetiger CloudWatch Logs Ingester Lambda Function"
    version     = "1.0"
    integration = "cloudwatch-logs"
    updated     = timestamp()
  }
}

# Upload Filter Manager Lambda package to S3
resource "aws_s3_object" "filter_manager_lambda" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/cloudwatch/logs/lambda/filter_manager.zip"
  source = data.archive_file.filter_manager.output_path

  content_type = "application/zip"
  etag         = data.archive_file.filter_manager.output_md5

  metadata = {
    description = "Firetiger CloudWatch Logs Subscription Filter Manager Lambda Function"
    version     = "1.0"
    integration = "cloudwatch-logs"
    updated     = timestamp()
  }
}

# Upload CloudFormation template to S3
resource "aws_s3_object" "cloudformation_template" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/cloudwatch/logs/cloudformation-template.yaml"
  source = "${path.module}/cloudformation/template.yaml"

  content_type = "text/yaml"
  etag         = filemd5("${path.module}/cloudformation/template.yaml")

  # Object will be publicly accessible via bucket policy

  metadata = {
    description = "Firetiger CloudWatch Logs Integration CloudFormation Template"
    version     = "1.0"
    integration = "ingest-cloudwatch-logs"
    updated     = timestamp()
  }
}

# Upload CloudFormation template with IAM role to S3
resource "aws_s3_object" "cloudformation_template_with_iam" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/cloudwatch/logs/ingest-and-iam-onboarding.yaml"
  source = "${path.module}/cloudformation/ingest-and-iam-onboarding.yaml"

  content_type = "text/yaml"
  etag         = filemd5("${path.module}/cloudformation/ingest-and-iam-onboarding.yaml")

  metadata = {
    description = "Firetiger CloudWatch Logs Integration with IAM Role CloudFormation Template"
    version     = "1.0"
    integration = "ingest-cloudwatch-logs"
    updated     = timestamp()
  }
}

# Outputs for reference
output "lambda_s3_urls" {
  description = "S3 URLs for Lambda packages"
  value = {
    ingester       = "s3://${data.aws_s3_bucket.firetiger_public.id}/${aws_s3_object.ingester_lambda.key}"
    filter_manager = "s3://${data.aws_s3_bucket.firetiger_public.id}/${aws_s3_object.filter_manager_lambda.key}"
  }
}

output "lambda_https_urls" {
  description = "HTTPS URLs for Lambda packages"
  value = {
    ingester       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.ingester_lambda.key}"
    filter_manager = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.filter_manager_lambda.key}"
  }
}

output "cloudformation_template_url" {
  description = "HTTPS URL for CloudFormation template"
  value       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template.key}"
}

output "cloudformation_template_with_iam_url" {
  description = "HTTPS URL for CloudFormation template with IAM role"
  value       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template_with_iam.key}"
}

output "cloudformation_quick_deploy_url" {
  description = "One-click CloudFormation deployment URL"
  value       = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template.key}&stackName=firetiger-ingest-cloudwatch-logs"
}

output "cloudformation_quick_deploy_with_iam_url" {
  description = "One-click CloudFormation deployment URL with IAM role"
  value       = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template_with_iam.key}&stackName=firetiger-ingest-and-iam-onboarding"
}

