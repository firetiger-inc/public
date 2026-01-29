# ==============================================================================
# Upload Cloud Function source to GCS
#
# This configuration packages the Cloud Function source code into a ZIP file
# and uploads it to the firetiger-public-gcp GCS bucket for use in gcloud
# deployment commands.
# ==============================================================================

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "firetiger-terraform"
    key    = "public/ingest/gcp/cloud-logging/terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

data "google_storage_bucket" "firetiger_public" {
  name = "firetiger-public"
}

# Package Cloud Function source code
data "archive_file" "cloud_function" {
  type        = "zip"
  output_path = "${path.module}/build/function.zip"

  source {
    content  = file("${path.module}/src/main.py")
    filename = "main.py"
  }

  source {
    content  = file("${path.module}/src/requirements.txt")
    filename = "requirements.txt"
  }
}

# Upload Cloud Function package to GCS
resource "google_storage_bucket_object" "cloud_function" {
  name   = "ingest/gcp/cloud-logging/function.zip"
  bucket = data.google_storage_bucket.firetiger_public.name
  source = data.archive_file.cloud_function.output_path

  content_type = "application/zip"

  metadata = {
    description = "Firetiger Cloud Logging Forwarder Cloud Function"
    version     = "1.0"
    integration = "cloud-logging"
  }
}

# Outputs for reference
output "function_gcs_url" {
  description = "GCS URL for Cloud Function package"
  value       = "gs://${data.google_storage_bucket.firetiger_public.name}/${google_storage_bucket_object.cloud_function.name}"
}

output "function_https_url" {
  description = "HTTPS URL for Cloud Function package"
  value       = "https://storage.googleapis.com/${data.google_storage_bucket.firetiger_public.name}/${google_storage_bucket_object.cloud_function.name}"
}
