# aws/configuration

This terraform module manages the initial configuration of a customer account
to allow creating a Firetiger deployment on AWS.

The module is intended to manage security-sensitive resources, and be executed
either by Firetiger or by the customer directly.

## Usage

The module requires the following variables as input:

| Variable     | Description                                             |
| ------------ | ------------------------------------------------------- |
| `bucket`     | Name of the S3 bucket that will hold the Firetiger data |
| `vpc_id`     | The VPC in which resources will be deployed             |
| `subnet_ids` | A list of subnets in which resources will be deployed   |

> :info: The S3 bucket is automatically created by the configuration module,
> you do not need to create it ahead of time.

> :warning: The subnets must have a route to AWS services, either through
> an internet gateway or via VPC endpoints.

Here is an example of how to instantiate the module:

```hcl
module "firetiger_configuration" {
  source = "github.com/firetiger-inc/public/aws/configuration"
  bucket = "<bucket>"
}

output "firetiger_deployment_role_arn" {
  value = module.firetiger_configuration.deployment_role_arn
}
```

Once the configuration is complete, output the deployment role ARN and give it
to the Firetiger team to have them trigger the deployment to your account. The
ARN should be:

    arn:aws:iam::<account-id>:role/FiretigerDeploymentRole@<bucket>
