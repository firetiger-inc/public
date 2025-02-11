locals {
  firetiger_service_account = "deployer@firetiger-control-plane.iam.gserviceaccount.com"

  deployer_iam_role_bindings = [
    "artifactregistry.admin",
    "bigquery.admin",
    "iam.serviceAccountUser",
    "logging.configWriter",
    "run.admin",
    "pubsub.admin",
    "resourcemanager.projectIamAdmin",
    "secretmanager.admin",
    "serviceusage.serviceUsageAdmin",
    "storage.admin",
    "dns.reader"
  ]

  dataplane_iam_role_bindings = [
    "logging.logWriter",
    "storage.admin",
  ]
}

resource "google_project_iam_member" "domain_binding" {
  project = data.google_project.current.project_id
  role    = "roles/editor"
  member  = "domain:firetiger.com"
}

# Deployer
resource "google_project_iam_member" "role_binding" {
  for_each = toset(local.deployer_iam_role_bindings)
  project  = data.google_project.current.project_id
  role     = format("roles/%s", each.value)
  member   = format("serviceAccount:%s", local.firetiger_service_account)
}

# Data Plane
resource "google_service_account" "dataplane" {
  account_id = "${var.bucket}-dataplane"
}

resource "google_project_iam_member" "dataplane_role_binding" {
  for_each = toset(local.dataplane_iam_role_bindings)
  project  = data.google_project.current.project_id
  role     = format("roles/%s", each.value)
  member   = format("serviceAccount:%s", google_service_account.dataplane.email)
}

