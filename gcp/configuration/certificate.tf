locals {
  # can only contain alphnumerics and dashes:
  # https://cloud.google.com/dns/docs/error-messages#invalidfieldvalue
  subdomain_name = format("%s.firetigerapi.com", var.bucket)
}

resource "google_dns_managed_zone" "subdomain_zone" {
  name     = replace(var.bucket, "/[^a-zA-Z0-9-]+/", "-")
  dns_name = format("%s.", local.subdomain_name)
}
