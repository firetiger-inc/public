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
