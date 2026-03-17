# ==============================================================================
# Upload WorkOS OpenAPI spec to S3
#
# When to update:
# - WorkOS API spec changes (new endpoints, updated schemas)
#
# When changing, also update:
# - openapi.json in this directory (source of truth)
# ==============================================================================

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "firetiger-terraform"
    key    = "public/connections/workos/terraform.tfstate"
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

resource "aws_s3_object" "openapi_spec" {
  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "connections/workos/openapi.json"
  source = "${path.module}/openapi.json"

  content_type = "application/json"
  etag         = filemd5("${path.module}/openapi.json")

  metadata = {
    description = "WorkOS API OpenAPI Specification"
  }
}

output "openapi_s3_url" {
  description = "S3 URL for WorkOS OpenAPI spec"
  value       = "s3://${data.aws_s3_bucket.firetiger_public.id}/${aws_s3_object.openapi_spec.key}"
}

output "openapi_https_url" {
  description = "HTTPS URL for WorkOS OpenAPI spec"
  value       = "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${aws_s3_object.openapi_spec.key}"
}
