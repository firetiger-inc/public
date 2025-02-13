variable "bucket" {
  type = string
}

variable "region" {
  type = string
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
  dataplane_account_id         = replace(var.bucket, "/[^a-zA-Z0-9-]+/", "-")
  bigquery_connection          = var.bigquery_connection != null ? split(".", var.bigquery_connection) : ["US", var.bucket]
  bigquery_connection_location = local.bigquery_connection[0]
  bigquery_connection_name     = local.bigquery_connection[1]
  bigquery_dataset_name        = var.bigquery_dataset_name != null ? var.bigquery_dataset_name : replace(var.bucket, "/[^a-zA-Z0-9_]+/", "_")
  tables                       = ["logs", "metrics", "traces"]
}

data "google_project" "current" {}
