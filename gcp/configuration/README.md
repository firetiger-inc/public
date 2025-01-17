# gcp/configuration

This terraform module manages the initial configuration of a customer account
to allow creating a Firetiger deployment on GCP.

The module is intended to manage security-sensitive resources, and be executed
either by Firetiger or by the customer directly.

## Usage

The module required the following variables as input:

| Variable     | Description                                             |
| ------------ | ------------------------------------------------------- |
| `bucket`     | Name of the S3 bucket that will hold the Firetiger data |
| `region`     | Region where the Firetiger resources will be deployed   |

> :info: The S3 bucket is automaticaly created by the configuration module,
> you do not need to create it ahead of time.

> :warning: The subnets must have a route to AWS services, either through
> an internet gateway or via VPC endpoints.

Here is an example of how to instantiate the module:

```hcl
module "firetiger_configuration" {
  source = "github.com/firetiger-inc/public/gcp/configuration"
  bucket = "<bucket>"
  region = "<region>"
}
```
