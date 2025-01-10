resource "aws_ecs_cluster" "deployment" {
  name = replace(aws_s3_bucket.deployment.id, ".", "_")
}

resource "aws_cloudwatch_log_group" "deployment" {
  name              = format("/ecs/%s", aws_s3_bucket.deployment.id)
  retention_in_days = 7

  lifecycle {
    create_before_destroy = true
  }
}
