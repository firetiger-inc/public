output "vpc_id" {
  value = var.vpc_id
}

output "subnet_ids" {
  value = var.subnet_ids
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

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.deployment.arn
}

output "cloudwatch_log_group_arn" {
  value = aws_cloudwatch_log_group.deployment.arn
}

output "service_discovery_namespace_arn" {
  value = aws_service_discovery_http_namespace.deployment.arn
}

output "task_role_arn" {
  value      = aws_iam_role.execution.arn
  depends_on = [aws_iam_role_policy.task]
}

output "task_role_policy" {
  value = jsondecode(aws_iam_role_policy.task.policy)
}

output "execution_role_arn" {
  value      = aws_iam_role.execution.arn
  depends_on = [aws_iam_role_policy.execution]
}

output "execution_role_policy" {
  value = jsondecode(aws_iam_role_policy.execution.policy)
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
  value = aws_glue_catalog_database.iceberg.arn
}

output "glue_table_arns" {
  value = {
    for table, glue in aws_glue_catalog_table.iceberg : table => glue.arn
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
