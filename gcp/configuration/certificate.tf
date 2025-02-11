locals {
  subdomain_name = format("%s.firetigerapi.com", var.bucket)
}

resource "google_dns_managed_zone" "subdomain_zone" {
  name     = var.bucket
  dns_name = local.subdomain_name
}
