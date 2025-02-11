variable "bucket" {
  type = string
}

variable "region" {
  type = string
}

locals {
  tables = ["logs", "metrics", "traces"]
}

data "google_project" "current" {}

locals {
  deployment_name = replace(replace(var.bucket, "_", "-"), ".", "-")
}
