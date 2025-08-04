# ==============================================================================
# Upload CloudFormation template to S3
# 
# This configuration uploads the CloudFormation template to the 
# firetiger-public S3 bucket for one-click deployment.
# ==============================================================================

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "firetiger-terraform"
    key    = "public/ingest/aws/ecs/events/terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_s3_bucket" "firetiger_public" {
  bucket = "firetiger-public"
}

# Upload CloudFormation template to S3
resource "aws_s3_object" "cloudformation_template" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "ingest/aws/ecs/events/cloudformation-template.yaml"
  source = "${path.module}/cloudformation/template.yaml"

  content_type = "text/yaml"
  etag         = filemd5("${path.module}/cloudformation/template.yaml")

  # Object will be publicly accessible via bucket policy

  metadata = {
    description = "Firetiger ECS Events Integration CloudFormation Template"
    version     = "1.0"
    integration = "ingest-ecs-events"
    updated     = timestamp()
  }
}

# Outputs for reference
output "cloudformation_template_url" {
  description = "HTTPS URL for CloudFormation template"
  value       = "https://s3.amazonaws.com/${data.aws_s3_bucket.firetiger_public.id}/${aws_s3_object.cloudformation_template.key}"
}

output "cloudformation_quick_deploy_url" {
  description = "One-click CloudFormation deployment URL"
  value       = "https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/${data.aws_s3_bucket.firetiger_public.id}/${aws_s3_object.cloudformation_template.key}&stackName=firetiger-ingest-ecs-events"
}

