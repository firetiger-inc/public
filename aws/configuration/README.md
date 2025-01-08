# aws/configuration

This terraform module manages the initial configuration of a customer account
to allow creating a Firetiger deployment on AWS.

The module is intended to manage security-sensitive resources, and be executed
either by Firetiger or by the customer directly.

## Usage

The module required the following variables as input:

| Variable     | Description                                            |
| ------------ | ------------------------------------------------------ |
| `bucket`     | Name of the S3 bucket that will hold the customer data |
| `vpc_id`     | VPC to deploy Firetiger in (or use the default VPC)    |

Here is an example of how to instantiate the module:

```hcl
variable "bucket" {
  type = string
}

data "aws_vpc" "default" {
  default = true
}

module "configuration" {
  source = "github.com/firetiger-inc/public/aws/configuration"
  bucket = var.bucket
  vpc_id = data.aws_vpc.default.id
}

output "configuration" {
  value = module.configuration
}
```
