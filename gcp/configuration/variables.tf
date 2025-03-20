variable "bucket" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9.-]{3,63}$", var.bucket))
    error_message = "Bucket name must be between 3 and 63 characters, and can only contain lowercase letters, numbers, dots, and hyphens."
  }
}

variable "region" {
  type = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be in the format 'region-name' (e.g., 'us-central1')."
  }
}

variable "catalog_name" {
  type    = string
  default = "firetiger"
}

variable "bigquery_dataset_name" {
  type    = string
  default = null
}

variable "bigquery_connection" {
  type    = string
  default = null

  validation {
    condition     = var.bigquery_connection == null ? true : (length(split(".", var.bigquery_connection)) == 2)
    error_message = "The BigQuery connection name must include a location and name. Ex: us.firetiger-dev-1"
  }
}

locals {
  deployment                   = replace(var.bucket, "/[^a-zA-Z0-9-]+/", "-")
  dataplane_account_id         = local.deployment
  bigquery_connection          = var.bigquery_connection != null ? split(".", var.bigquery_connection) : ["US", var.bucket]
  bigquery_connection_location = local.bigquery_connection[0]
  bigquery_connection_name     = local.bigquery_connection[1]
  bigquery_dataset_name        = var.bigquery_dataset_name != null ? var.bigquery_dataset_name : replace(var.bucket, "/[^a-zA-Z0-9_]+/", "_")
  tables                       = ["logs", "metrics", "traces"]
}

data "google_project" "current" {}
