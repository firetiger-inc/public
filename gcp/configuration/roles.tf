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
    "dns.admin",
    "compute.admin",
    "compute.networkAdmin",
    "certificatemanager.owner",
    "cloudsql.admin"
  ]

  dataplane_iam_role_bindings = [
    "logging.logWriter",
    "storage.admin",
    "secretmanager.secretAccessor"
  ]
}

resource "google_project_iam_member" "domain_binding" {
  project = data.google_project.current.project_id
  role    = "roles/editor"
  member  = "domain:firetiger.com"

  depends_on = [
    google_project_service.enable["iam.googleapis.com"],
  ]
}

# Deployer
resource "google_project_iam_member" "role_binding" {
  for_each = toset(local.deployer_iam_role_bindings)
  project  = data.google_project.current.project_id
  role     = format("roles/%s", each.value)
  member   = format("serviceAccount:%s", local.firetiger_service_account)

  depends_on = [
    google_project_service.enable["iam.googleapis.com"],
  ]
}

# Data Plane
resource "google_service_account" "dataplane" {
  account_id = local.dataplane_account_id

  depends_on = [
    google_project_service.enable["iam.googleapis.com"],
  ]
}

resource "google_project_iam_member" "dataplane_role_binding" {
  for_each = toset(local.dataplane_iam_role_bindings)
  project  = data.google_project.current.project_id
  role     = format("roles/%s", each.value)
  member   = format("serviceAccount:%s", google_service_account.dataplane.email)

  depends_on = [
    google_project_service.enable["iam.googleapis.com"],
  ]
}

