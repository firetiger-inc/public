resource "aws_security_group" "frontend" {
  name        = format("FiretigerFrontend@%s", aws_s3_bucket.deployment.id)
  description = "Security group for the Firetiger frontend load balancer"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    delete = "2m"
  }
}

locals {
  frontend_ports = {
    http  = 80
    https = 443
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv4" {
  for_each          = local.frontend_ports
  security_group_id = aws_security_group.frontend.id
  description       = "Allow IPv4 traffic from the internet to the Firetiger frontend load balancer on port ${each.value}"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = each.value
  to_port     = each.value
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv6" {
  for_each          = local.frontend_ports
  security_group_id = aws_security_group.frontend.id
  description       = "Allow IPv6 traffic from the internet to the Firetiger frontend load balancer on port ${each.value}"

  cidr_ipv6   = "::/0"
  from_port   = each.value
  to_port     = each.value
  ip_protocol = "tcp"
}

resource "aws_security_group" "backend" {
  name        = format("FiretigerBackend@%s", aws_s3_bucket.deployment.id)
  description = "Security group for the Firetiger backend services"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    delete = "2m"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_self" {
  security_group_id = aws_security_group.backend.id
  description       = "Allow traffic between all Firetiger services"

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.backend.id
}

resource "aws_vpc_security_group_egress_rule" "allow_ipv4" {
  security_group_id = aws_security_group.backend.id
  description       = "Allow all outbound IPv4 traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_ipv6" {
  security_group_id = aws_security_group.backend.id
  description       = "Allow all outbound IPv6 traffic"

  cidr_ipv6   = "::/0"
  ip_protocol = "-1"
}
