variable "bucket" {
  type = string
}

variable "table" {
  type = string
}

variable "properties" {
  type    = map(string)
  default = {}
}

locals {
  properties = merge({
    "commit.manifest.target-history-count" = "10"
    "commit.retry.num-retries"             = "10"
    "commit.retry.min-wait-ms"             = "10"
    "commit.retry.max-wait-ms"             = "3000"
    "commit.retry.total-timeout-ms"        = "30000"
    "history.expire.min-snapshots-to-keep" = "1"
  }, var.properties)

  metadata_location = format("%s/metadata/000000000-%s.metadata.json", var.table, random_uuid.table.result)
}

resource "time_static" "table" {}
resource "random_uuid" "table" {}

output "bucket" {
  value = var.bucket
}

output "table" {
  value = var.table
}

output "properties" {
  value = local.properties
}

output "metadata_location" {
  value = local.metadata_location
}

output "metadata" {
  value = jsonencode({
    format-version       = 2
    table-uuid           = random_uuid.table.result
    location             = format("%s/%s", var.bucket, var.table)
    last-sequence-number = 0
    last-updated-ms      = time_static.table.unix * 1000,
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
    metadata-log = [{
      timestamp-ms  = time_static.table.unix * 1000
      metadata-file = local.metadata_location
    }]
    refs       = {}
    properties = local.properties
  })
}
