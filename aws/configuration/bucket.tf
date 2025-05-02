module "iceberg_table_metadata" {
  for_each = toset(local.tables)
  source   = "../../iceberg/table_metadata"
  bucket   = format("s3://%s", var.bucket)
  table    = each.value
}

resource "aws_s3_bucket" "deployment" {
  bucket        = var.bucket
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  rule {
    id     = "tmp-cleanup"
    status = "Enabled"

    filter {
      prefix = "tmp/"
    }

    expiration {
      days = 2
    }
  }
}

resource "aws_s3_object" "initial_table_metadata" {
  for_each     = module.iceberg_table_metadata
  bucket       = aws_s3_bucket.deployment.id
  key          = each.value.metadata_location
  content      = each.value.metadata
  content_type = "application/json"
}

resource "aws_s3_object" "configuration" {
  bucket = aws_s3_bucket.deployment.id
  key    = "firetiger/configuration.json"

  content_type = "application/json"
  content = jsonencode({
    region                           = data.aws_region.current.name
    account-id                       = data.aws_caller_identity.current.account_id
    vpc-id                           = var.vpc_id
    subnet-ids                       = var.subnet_ids
    bucket                           = var.bucket
    resource-allocation              = var.resource_allocation
    ecs-cluster-name                 = aws_ecs_cluster.deployment.name
    cloudwatch-log-group-name        = aws_cloudwatch_log_group.deployment.name
    service-discovery-namespace-name = aws_service_discovery_http_namespace.deployment.name
    athena-workgroup-name            = aws_athena_workgroup.deployment.name
    basic-auth = {
      secrets = {
        ingest = aws_secretsmanager_secret.ingest_basic_auth.arn
        query  = aws_secretsmanager_secret.query_basic_auth.arn
      }
    }
  })
}
