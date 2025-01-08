output "deployment" {
  value = format("aws.%s", aws_s3_bucket.deployment.id)
}

output "vpc_id" {
  value = var.vpc_id
}

output "zone_id" {
  value = aws_route53_zone.deployment.zone_id
}

output "domain_name" {
  value = aws_acm_certificate.deployment.domain_name
}

output "certificate_arn" {
  value = aws_acm_certificate.deployment.arn
}

output "iceberg_namespace" {
  value = aws_s3_bucket.deployment.id
}

output "iceberg_tables" {
  value = {
    logs    = format("%s.logs", aws_s3_bucket.deployment.id)
    metrics = format("%s.metrics", aws_s3_bucket.deployment.id)
    traces  = format("%s.traces", aws_s3_bucket.deployment.id)
  }
}

output "task_role_name" {
  value      = aws_iam_role.execution.name
  depends_on = [aws_iam_role_policy.task]
}

output "task_role_arn" {
  value      = aws_iam_role.execution.arn
  depends_on = [aws_iam_role_policy.task]
}

output "task_role_policy" {
  value = jsondecode(aws_iam_role_policy.task.policy)
}

output "execution_role_name" {
  value      = aws_iam_role.execution.name
  depends_on = [aws_iam_role_policy.execution]
}

output "execution_role_arn" {
  value      = aws_iam_role.execution.arn
  depends_on = [aws_iam_role_policy.execution]
}

output "execution_role_policy" {
  value = jsondecode(aws_iam_role_policy.execution.policy)
}

output "deployment_role_name" {
  value      = aws_iam_role.deployment.name
  depends_on = [aws_iam_role_policy.deployment]
}

output "deployment_role_arn" {
  value      = aws_iam_role.deployment.arn
  depends_on = [aws_iam_role_policy.deployment]
}

output "deployment_role_policy" {
  value = jsondecode(aws_iam_role_policy.deployment.policy)
}

output "frontend_security_group_id" {
  value = aws_security_group.frontend.id
  depends_on = [
    aws_vpc_security_group_ingress_rule.allow_ipv4,
    aws_vpc_security_group_ingress_rule.allow_ipv6,
  ]
}

output "backend_security_group_id" {
  value = aws_security_group.backend.id
  depends_on = [
    aws_vpc_security_group_ingress_rule.allow_self,
    aws_vpc_security_group_egress_rule.allow_ipv4,
    aws_vpc_security_group_egress_rule.allow_ipv6,
  ]
}

output "s3_bucket_id" {
  value = aws_s3_bucket.deployment.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.deployment.arn
}

output "glue_catalog_arn" {
  value = data.aws_arn.catalog.arn
}

output "glue_database_arn" {
  value = data.aws_arn.database.arn
}

output "glue_table_arns" {
  value = {
    logs    = data.aws_arn.logs.arn
    metrics = data.aws_arn.metrics.arn
    traces  = data.aws_arn.traces.arn
  }
}

output "basic_auth_secret_arns" {
  value = {
    ingest = aws_secretsmanager_secret.ingest_basic_auth.arn
    query  = aws_secretsmanager_secret.query_basic_auth.arn
  }
  depends_on = [
    aws_secretsmanager_secret_version.ingest_basic_auth,
    aws_secretsmanager_secret_version.query_basic_auth,
  ]
}
