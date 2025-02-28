locals {
  services = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "dns.googleapis.com",
    "compute.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com"
  ]
}

resource "google_project_service" "enable" {
  for_each           = toset(local.services)
  service            = each.value
  disable_on_destroy = false
}

