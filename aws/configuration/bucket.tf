resource "aws_s3_bucket" "deployment" {
  bucket        = var.bucket
  force_destroy = true
}
