resource "aws_route53_zone" "deployment" {
  name    = format("%s.firetigerapi.com", var.bucket)
  comment = "DNS zone for the Firetiger records"

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
  }
}

resource "aws_acm_certificate" "deployment" {
  domain_name       = aws_route53_zone.deployment.name
  validation_method = "DNS"

  subject_alternative_names = [
    format("*.%s", aws_route53_zone.deployment.name),
  ]

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
  }

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
