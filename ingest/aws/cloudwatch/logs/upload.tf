# ==============================================================================
# Upload Lambda packages and CloudFormation templates to S3
#
# Lambda zips are uploaded to regional buckets (firetiger-public-{region})
# because Lambda requires code to be in the same region as the function.
# CloudFormation templates are uploaded to the global firetiger-public bucket.
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

# ==============================================================================
# Supported regions
# ==============================================================================

locals {
  supported_regions = toset([
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
    "ca-central-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "eu-central-1",
    "eu-north-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "ap-northeast-1",
    "ap-northeast-2",
    "ap-south-1",
    "sa-east-1",
  ])
}

# ==============================================================================
# Build Lambda deployment packages
# ==============================================================================

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

# ==============================================================================
# Upload Lambda zips to all regional buckets
# ==============================================================================

resource "aws_s3_object" "ingester_lambda" {
  for_each = local.supported_regions

  bucket       = "firetiger-public-${each.key}"
  key          = "ingest/aws/cloudwatch/logs/lambda/ingester.zip"
  source       = data.archive_file.ingester.output_path
  content_type = "application/zip"
  etag         = data.archive_file.ingester.output_md5

  metadata = {
    description = "Firetiger CloudWatch Logs Ingester Lambda Function"
    version     = "1.0"
    integration = "cloudwatch-logs"
    updated     = timestamp()
  }
}

resource "aws_s3_object" "filter_manager_lambda" {
  for_each = local.supported_regions

  bucket       = "firetiger-public-${each.key}"
  key          = "ingest/aws/cloudwatch/logs/lambda/filter_manager.zip"
  source       = data.archive_file.filter_manager.output_path
  content_type = "application/zip"
  etag         = data.archive_file.filter_manager.output_md5

  metadata = {
    description = "Firetiger CloudWatch Logs Subscription Filter Manager Lambda Function"
    version     = "1.0"
    integration = "cloudwatch-logs"
    updated     = timestamp()
  }
}

# ==============================================================================
# Upload CloudFormation templates to global bucket
# (Templates are not region-specific, only Lambda code must be co-regional)
# ==============================================================================

data "aws_s3_bucket" "firetiger_public" {
  bucket = "firetiger-public"
}

resource "aws_s3_object" "cloudformation_template" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/cloudwatch/logs/cloudformation-template.yaml"
  source = "${path.module}/cloudformation/template.yaml"

  content_type = "text/yaml"
  etag         = filemd5("${path.module}/cloudformation/template.yaml")

  metadata = {
    description = "Firetiger CloudWatch Logs Integration CloudFormation Template"
    version     = "1.0"
    integration = "ingest-cloudwatch-logs"
    updated     = timestamp()
  }
}

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

resource "aws_s3_object" "cloudformation_template_iam_only" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/cloudwatch/logs/iam-only.yaml"
  source = "${path.module}/cloudformation/iam-only.yaml"

  content_type = "text/yaml"
  etag         = filemd5("${path.module}/cloudformation/iam-only.yaml")

  metadata = {
    description = "Firetiger IAM-Only CloudFormation Template for cross-account access"
    version     = "1.0"
    integration = "iam-role"
    updated     = timestamp()
  }
}

# ==============================================================================
# Outputs
# ==============================================================================

output "cloudformation_template_url" {
  description = "HTTPS URL for CloudFormation template"
  value       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template.key}"
}

output "cloudformation_template_onboarding_url" {
  description = "HTTPS URL for CloudFormation template with IAM role"
  value       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template_with_iam.key}"
}

output "cloudformation_quick_deploy_url" {
  description = "One-click CloudFormation deployment URL"
  value       = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template.key}&stackName=firetiger-ingest-cloudwatch-logs"
}

output "cloudformation_quick_deploy_onboarding_url" {
  description = "One-click CloudFormation deployment URL with IAM role"
  value       = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template_with_iam.key}&stackName=firetiger-ingest-and-iam-onboarding"
}

output "cloudformation_iam_only_template_url" {
  description = "HTTPS URL for IAM-only CloudFormation template"
  value       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template_iam_only.key}"
}

output "cloudformation_quick_deploy_iam_only_url" {
  description = "One-click CloudFormation deployment URL for IAM-only template"
  value       = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.cloudformation_template_iam_only.key}&stackName=firetiger-iam-role"
}

output "supported_regions" {
  description = "AWS regions where Lambda packages are available"
  value       = local.supported_regions
}
