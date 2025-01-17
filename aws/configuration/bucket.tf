resource "aws_s3_bucket" "deployment" {
  bucket        = var.bucket
  force_destroy = true
}

resource "time_static" "created_at" {}

resource "random_uuid" "initial_table_metadata" {
  for_each = toset(local.tables)
}

resource "aws_s3_object" "initial_table_metadata" {
  for_each = random_uuid.initial_table_metadata
  bucket   = aws_s3_bucket.deployment.id

  # metadata_location
  key = format("%s/metadata/000000000-%s.metadata.json", each.key, each.value.result)

  # metadata
  content_type = "application/json"
  content = jsonencode({
    format-version       = 2
    table-uuid           = each.value.result
    location             = format("s3://%s/%s", aws_s3_bucket.deployment.id, each.key)
    last-sequence-number = 0
    last-updated-ms      = time_static.created_at.unix * 1000,
    last-column-id       = 0
    current-schema-id    = 0
    schemas = [{
      schema-id = 0
      type      = "struct"
      fields    = []
    }]
    default-spec-id   = 0
    last-partition-id = 999
    partition-specs = [{
      spec-id = 0
      fields  = []
    }]
    default-sort-order-id = 0
    sort-orders = [{
      order-id = 0
      fields   = []
    }]
    snapshots    = []
    snapshot-log = []
    metadata-log = []
    refs         = {}
    properties = {
      "commit.manifest.target-history-count" = "10"
      "commit.retry.num-retries"             = "10"
      "commit.retry.min-wait-ms"             = "10"
      "commit.retry.max-wait-ms"             = "3000"
      "commit.retry.total-timeout-ms"        = "30000"
      "history.expire.min-snapshots-to-keep" = "1"
      "write.data.location"                  = format("s3://%s/%s/data", aws_s3_bucket.deployment.id, each.key)
    }
  })

  tags = {
    FiretigerDeployment = var.bucket
    FiretigerTable      = each.key
  }
}

resource "aws_s3_object" "configuration" {
  bucket = aws_s3_bucket.deployment.id
  key    = "firetiger/configuration.json"

  content_type = "application/json"
  content = jsonencode({
    region                           = data.aws_region.current.name
    account_id                       = data.aws_caller_identity.current.account_id
    vpc_id                           = var.vpc_id
    subnet_ids                       = var.subnet_ids
    bucket                           = var.bucket
    resource_allocation              = var.resource_allocation
    ecs_cluster_name                 = aws_ecs_cluster.deployment.name
    cloudwatch_log_group_name        = aws_cloudwatch_log_group.deployment.name
    service_discovery_namespace_name = aws_service_discovery_http_namespace.deployment.name
  })

  tags = {
    FiretigerDeployment = var.bucket
  }
}
