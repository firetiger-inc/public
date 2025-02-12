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

variable "bigquery_connection_name" {
  type    = string
  default = null
}

locals {
  dataplane_account_id     = format("%s-dataplane", replace(var.bucket, "/[^a-zA-Z0-9-]+/", "-"))
  bigquery_connection_name = var.bigquery_connection_name != null ? var.bigquery_connection_name : var.bucket
  bigquery_dataset_name    = var.bigquery_dataset_name != null ? var.bigquery_dataset_name : replace(var.bucket, "/[^a-zA-Z0-9_]+/", "_")
  tables                   = ["logs", "metrics", "traces"]
}

data "google_project" "current" {}
