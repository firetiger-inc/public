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

locals {
  tables = ["logs", "metrics", "traces"]
}

data "google_project" "current" {}

locals {
  deployment_name = replace(replace(var.bucket, "-", "_"), ".", "_")
}
