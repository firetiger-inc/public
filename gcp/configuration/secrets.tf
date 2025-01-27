resource "random_password" "ingest_basic_auth" {
  length  = 32
  special = false
}

resource "random_password" "query_basic_auth" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "ingest_basic_auth" {
  secret_id = format("%s-basic-auth-ingest", google_storage_bucket.deployment.name)

  labels = {
    firetiger-deployment  = google_storage_bucket.deployment.name
    firetiger-secret-name = "firetiger-basic-auth-ingest"
  }

  depends_on = [
    google_project_service.enable["secretsmanager"],
  ]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "query_basic_auth" {
  secret_id = format("%s-basic-auth-query", google_storage_bucket.deployment.name)

  labels = {
    firetiger-deployment  = google_storage_bucket.deployment.name
    firetiger-secret-name = "firetiger-basic-auth-query"
  }

  depends_on = [
    google_project_service.enable["secretsmanager"],
  ]

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "ingest_basic_auth" {
  secret      = google_secret_manager_secret.ingest_basic_auth.id
  secret_data = random_password.ingest_basic_auth.result

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "query_basic_auth" {
  secret      = google_secret_manager_secret.query_basic_auth.id
  secret_data = random_password.query_basic_auth.result

  lifecycle {
    ignore_changes = [secret_data]
  }
}
