resource "google_dns_managed_zone" "subdomain_zone" {
  name = local.deployment
  # can only contain alphnumerics and dashes:
  # https://cloud.google.com/dns/docs/error-messages#invalidfieldvalue
  dns_name = format("%s.firetigerapi.com.", local.deployment)

  depends_on = [
    google_project_service.enable["dns.googleapis.com"],
  ]
}
