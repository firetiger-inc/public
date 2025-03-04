locals {
  # replace invalid characters with underscores
  iceberg_namespace = google_storage_bucket.deployment.name
}

module "iceberg_table_metadata" {
  for_each = toset(local.tables)
  source   = "../../iceberg/table_metadata"
  bucket   = format("gs://%s", var.bucket)
  table    = each.value
}

resource "google_storage_bucket" "deployment" {
  name                        = var.bucket
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [
    google_project_service.enable["storage.googleapis.com"],
  ]

  labels = {
    firetiger-deployment = var.bucket
  }
}

resource "google_storage_bucket_object" "catalog_namespace" {
  bucket = google_storage_bucket.deployment.name
  name   = format("catalogs/%s/namespaces/%s/properties.json", var.catalog_name, local.iceberg_namespace)
  content = jsonencode({
    catalog-name = var.catalog_name
    namespace    = local.iceberg_namespace
    properties   = {}
  })
}

resource "google_storage_bucket_object" "catalog_table" {
  for_each = module.iceberg_table_metadata
  bucket   = google_storage_bucket.deployment.name
  name     = format("catalogs/%s/namespaces/%s/tables/%s.json", var.catalog_name, local.iceberg_namespace, each.key)
  content = jsonencode({
    catalog-name      = var.catalog_name
    table-namespace   = local.iceberg_namespace
    table-name        = each.key
    metadata-location = format("gs://%s/%s", google_storage_bucket.deployment.name, each.value.metadata_location)
  })

  lifecycle {
    // ignore subsequent updates to the catalog table after the initial creation
    ignore_changes = [detect_md5hash]
  }
}


resource "google_storage_bucket_object" "initial_table_metadata" {
  for_each     = module.iceberg_table_metadata
  bucket       = google_storage_bucket.deployment.name
  name         = each.value.metadata_location
  content      = each.value.metadata
  content_type = "application/json"
}

resource "google_storage_bucket_object" "configuration" {
  bucket = google_storage_bucket.deployment.name
  name   = "firetiger/configuration.json"

  content_type = "application/json"
  content = jsonencode({
    project = data.google_project.current.project_id
    region  = var.region
    bucket  = google_storage_bucket.deployment.name
    basic-auth = {
      secrets = {
        ingest          = google_secret_manager_secret.ingest_basic_auth.id
        query           = google_secret_manager_secret.query_basic_auth.id
        replication_api = google_secret_manager_secret.replication_api.id
      }
    }
  })
}


# BigQuery resources
resource "google_project_iam_member" "bigquery_admin" {
  project = data.google_project.current.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataplane.email}"
}

resource "google_bigquery_dataset" "deployment" {
  dataset_id  = local.bigquery_dataset_name
  description = "Firetiger data for ${var.bucket}"
  labels = {
    "firetiger"  = "true"
    "deployment" = var.bucket
  }
}
resource "google_bigquery_connection" "connection" {
  connection_id = local.bigquery_connection_name
  location      = local.bigquery_connection_location
  friendly_name = "Firetiger: ${var.bucket}"
  description   = "Firetiger connection for ${var.bucket}"
  cloud_resource {}
}

resource "google_storage_bucket_iam_member" "bigquery_telemetry_storage_access" {
  bucket = google_storage_bucket.deployment.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_bigquery_connection.connection.cloud_resource[0].service_account_id}"
}
