variable "bucket" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "secrets_recovery_window_in_days" {
  type    = number
  default = 0
}

locals {
  cluster  = replace(aws_s3_bucket.deployment.id, ".", "_")
  database = replace(aws_s3_bucket.deployment.id, ".", "_")
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_arn" "catalog" {
  arn = format("arn:aws:glue:%s:%s:catalog",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
  )
}

data "aws_arn" "database" {
  arn = format("arn:aws:glue:%s:%s:database/%s",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
    local.database,
  )
}

data "aws_arn" "logs" {
  arn = format("arn:aws:glue:%s:%s:table/%s/logs",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
    local.database,
  )
}

data "aws_arn" "metrics" {
  arn = format("arn:aws:glue:%s:%s:table/%s/metrics",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
    local.database,
  )
}

data "aws_arn" "traces" {
  arn = format("arn:aws:glue:%s:%s:table/%s/traces",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
    local.database,
  )
}
