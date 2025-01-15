module "iceberg_table_metadata" {
  for_each = toset(local.tables)
  source   = "../../iceberg/table_metadata"
  bucket   = var.bucket
  table    = each.value
}

resource "google_storage_bucket" "deployment" {
  name                        = var.bucket
  location                    = upper(split("-", var.region)[0])
  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [
    google_project_service.enable["storage"],
  ]

  labels = {
    firetiger-deployment = var.bucket
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
    project                     = data.google_project.current.project_id
    region                      = var.region
    bucket                      = google_storage_bucket.deployment.name
    basic-auth-ingest-secret-id = google_secret_manager_secret.ingest_basic_auth.id
    basic-auth-query-secret-id  = google_secret_manager_secret.query_basic_auth.id
  })
}
