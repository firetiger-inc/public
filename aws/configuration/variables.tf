variable "bucket" {
  type = string
}

variable "vpc_id" {
  type     = string
  default  = null
  nullable = true
}

variable "subnet_ids" {
  type    = list(string)
  default = []
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

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_route_table" "default" {
  for_each  = toset(coalesce(var.subnet_ids, data.aws_subnets.default.ids))
  subnet_id = each.value
}

data "aws_subnet" "selected" {
  for_each = toset(local.subnet_ids)
}

check "subnet_ids_belong_to_the_vpc" {
  assert {
    condition = length(setintersection(
      toset(distinct([
        for subnet in data.aws_subnet.selected : subnet.vpc_id
      ])),
      toset([local.vpc_id]),
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

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Selects the VPC ID from the variable or the default VPC, the `one` function
  # will raise an error if no VPC ID was passeed as argument and there was no
  # default VPC in the account.
  vpc_id = one([
    for vpc_id in [var.vpc_id, try(data.aws_vpc.default[0].id, null)] :
    vpc_id if vpc_id != null
  ])

  # Selects the subnet IDs either from the input variable or the full list of
  # public subnets from the VPC.
  subnet_ids = [
    for subnet_id, route_table in data.aws_route_table.default :
    subnet_id if anytrue([
      for route in route_table.routes : route.gateway_id != null
    ])
  ]
}
