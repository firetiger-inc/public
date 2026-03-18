# ==============================================================================
# Upload OpenAPI specs to S3 for all connections
#
# When to update:
# - Any connection's API spec changes (new endpoints, updated schemas)
#
# To add a new connection:
# - Add a new directory under connections/ with an openapi.json file
# - Add the connection name to the `connections` local below
# ==============================================================================

locals {
  connections = toset(["vanta", "workos"])
}

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "firetiger-terraform"
    key    = "public/connections/terraform.tfstate"
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
  for_each = local.connections

  bucket = data.aws_s3_bucket.firetiger_public.id
  key    = "connections/${each.key}/openapi.json"
  source = "${path.module}/${each.key}/openapi.json"

  content_type = "application/json"
  etag         = filemd5("${path.module}/${each.key}/openapi.json")

  metadata = {
    description = "${title(each.key)} API OpenAPI Specification"
  }
}

output "openapi_s3_urls" {
  description = "S3 URLs for OpenAPI specs"
  value = {
    for name, obj in aws_s3_object.openapi_spec :
    name => "s3://${data.aws_s3_bucket.firetiger_public.id}/${obj.key}"
  }
}

output "openapi_https_urls" {
  description = "HTTPS URLs for OpenAPI specs"
  value = {
    for name, obj in aws_s3_object.openapi_spec :
    name => "https://${data.aws_s3_bucket.firetiger_public.bucket_regional_domain_name}/${obj.key}"
  }
}
