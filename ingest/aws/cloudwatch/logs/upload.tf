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
# Regional AWS providers
# ==============================================================================

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "ca-central-1"
  region = "ca-central-1"
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2"
}

provider "aws" {
  alias  = "eu-west-3"
  region = "eu-west-3"
}

provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "eu-north-1"
  region = "eu-north-1"
}

provider "aws" {
  alias  = "ap-southeast-1"
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "ap-southeast-2"
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "ap-northeast-1"
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "ap-northeast-2"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "ap-south-1"
  region = "ap-south-1"
}

provider "aws" {
  alias  = "sa-east-1"
  region = "sa-east-1"
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

module "upload_us_east_1" {
  source    = "./regional-upload"
  providers = { aws = aws.us-east-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_us_east_2" {
  source    = "./regional-upload"
  providers = { aws = aws.us-east-2 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_us_west_1" {
  source    = "./regional-upload"
  providers = { aws = aws.us-west-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_us_west_2" {
  source    = "./regional-upload"
  providers = { aws = aws.us-west-2 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_ca_central_1" {
  source    = "./regional-upload"
  providers = { aws = aws.ca-central-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_eu_west_1" {
  source    = "./regional-upload"
  providers = { aws = aws.eu-west-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_eu_west_2" {
  source    = "./regional-upload"
  providers = { aws = aws.eu-west-2 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_eu_west_3" {
  source    = "./regional-upload"
  providers = { aws = aws.eu-west-3 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_eu_central_1" {
  source    = "./regional-upload"
  providers = { aws = aws.eu-central-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_eu_north_1" {
  source    = "./regional-upload"
  providers = { aws = aws.eu-north-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_ap_southeast_1" {
  source    = "./regional-upload"
  providers = { aws = aws.ap-southeast-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_ap_southeast_2" {
  source    = "./regional-upload"
  providers = { aws = aws.ap-southeast-2 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_ap_northeast_1" {
  source    = "./regional-upload"
  providers = { aws = aws.ap-northeast-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_ap_northeast_2" {
  source    = "./regional-upload"
  providers = { aws = aws.ap-northeast-2 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_ap_south_1" {
  source    = "./regional-upload"
  providers = { aws = aws.ap-south-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
}

module "upload_sa_east_1" {
  source    = "./regional-upload"
  providers = { aws = aws.sa-east-1 }

  ingester_source       = data.archive_file.ingester.output_path
  ingester_etag         = data.archive_file.ingester.output_md5
  filter_manager_source = data.archive_file.filter_manager.output_path
  filter_manager_etag   = data.archive_file.filter_manager.output_md5
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
