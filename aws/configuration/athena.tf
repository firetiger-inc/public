resource "aws_athena_workgroup" "deployment" {
  name        = replace(var.bucket, ".", "-")
  description = "Athena workgroup for Firetiger deployment ${var.bucket}"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.bucket}/tmp/athena/"
    }
  }
}
