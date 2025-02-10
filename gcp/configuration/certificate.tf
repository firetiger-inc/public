locals {
  subdomain_name = format("%s.firetigerapi.com", local.deployment_name)
}

resource "google_dns_managed_zone" "subdomain_zone" {
  name     = var.bucket
  dns_name = subdomain_name
}
