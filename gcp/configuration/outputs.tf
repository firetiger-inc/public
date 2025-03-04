output "gs_bucket_id" {
  value = google_storage_bucket.deployment.id
}

output "basic_auth_secret_ids" {
  value = {
    ingest          = google_secret_manager_secret.ingest_basic_auth.id
    query           = google_secret_manager_secret.query_basic_auth.id
    replication_api = google_secret_manager_secret.replication_api_basic_auth.id
  }
  depends_on = [
    google_secret_manager_secret_version.ingest_basic_auth,
    google_secret_manager_secret_version.query_basic_auth,
    google_secret_manager_secret_version.replication_api_basic_auth,
  ]
}
