variable "bucket" {
  type = string
}

variable "vpc_id" {
  type = string

  validation {
    condition     = can(regex("vpc-[0-9a-f]{8,}", var.vpc_id))
    error_message = "VPC ID must be in the format 'vpc-<8 hex characters>'"
  }
}

variable "subnet_ids" {
  type = list(string)

  validation {
    condition     = alltrue([for subnet_id in var.subnet_ids : can(regex("subnet-[0-9a-f]{8,}", subnet_id))])
    error_message = "Subnet IDs must be in the format 'subnet-<8 hex characters>'"
  }
}

variable "secrets_recovery_window_in_days" {
  type    = number
  default = 0

  validation {
    condition     = var.secrets_recovery_window_in_days == 0 || (var.secrets_recovery_window_in_days >= 7 && var.secrets_recovery_window_in_days <= 30)
    error_message = "Secrets recovery window must be 0 or between 7 and 30 days"
  }
}

variable "resource_allocation" {
  type    = string
  default = "low"

  validation {
    condition     = contains(["low", "medium", "high"], var.resource_allocation)
    error_message = "Resource allocation must be low, medium, or high"
  }
}

locals {
  cluster  = replace(aws_s3_bucket.deployment.id, ".", "_")
  database = replace(aws_s3_bucket.deployment.id, ".", "_")
  tables   = ["logs", "metrics", "traces"]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.key
}

check "subnet_ids_belong_to_the_vpc" {
  assert {
    condition = length(setintersection(
      toset(distinct([for subnet in data.aws_subnet.selected : subnet.vpc_id])),
      toset([var.vpc_id]),
    )) == 1
    error_message = "Subnets must belong to the same VPC"
  }
}

check "subnet_ids_belong_to_at_least_two_availability_zones" {
  assert {
    condition = length(distinct([
      for subnet in data.aws_subnet.selected : subnet.availability_zone
    ])) >= 2
    error_message = "Subnets must belong to at least two availability zones"
  }
}
