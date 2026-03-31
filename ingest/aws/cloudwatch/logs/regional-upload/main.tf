terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_region" "current" {}

resource "aws_s3_object" "ingester" {
  bucket       = "firetiger-public-${data.aws_region.current.name}"
  key          = "ingest/aws/cloudwatch/logs/lambda/ingester.zip"
  source       = var.ingester_source
  content_type = "application/zip"
  etag         = var.ingester_etag

  metadata = {
    description = "Firetiger CloudWatch Logs Ingester Lambda Function"
    version     = "1.0"
    integration = "cloudwatch-logs"
    updated     = timestamp()
  }
}

resource "aws_s3_object" "filter_manager" {
  bucket       = "firetiger-public-${data.aws_region.current.name}"
  key          = "ingest/aws/cloudwatch/logs/lambda/filter_manager.zip"
  source       = var.filter_manager_source
  content_type = "application/zip"
  etag         = var.filter_manager_etag

  metadata = {
    description = "Firetiger CloudWatch Logs Subscription Filter Manager Lambda Function"
    version     = "1.0"
    integration = "cloudwatch-logs"
    updated     = timestamp()
  }
}
