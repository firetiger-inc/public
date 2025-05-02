provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_route53_zone" "deployment" {
  name    = format("%s.firetigerapi.com", var.bucket)
  comment = "DNS zone for the Firetiger records"
}

resource "aws_acm_certificate" "deployment" {
  domain_name       = aws_route53_zone.deployment.name
  validation_method = "DNS"

  subject_alternative_names = [
    format("*.%s", aws_route53_zone.deployment.name),
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "cloudfront" {
  # Cloudfront requires certificates to exist in us-east-1.
  provider          = aws.us-east-1
  domain_name       = aws_route53_zone.deployment.name
  validation_method = "DNS"

  subject_alternative_names = [
    format("*.%s", aws_route53_zone.deployment.name),
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.deployment.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.deployment.zone_id
}

resource "aws_route53_record" "cloudfront_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.deployment.zone_id
}
