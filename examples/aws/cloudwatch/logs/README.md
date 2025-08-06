# CloudWatch Logs Integration - Terraform Example

This example demonstrates how to deploy the Firetiger CloudWatch Logs integration using the GitHub-hosted Terraform module.

## Quick Start

1. Edit `main.tf` and replace `"your-password-here"` with your actual Firetiger password

2. Initialize and apply:
   ```bash
   terraform init
   terraform apply
   ```

## Configuration

The example is pre-configured with:
- Lambda function with 512MB memory and 5-minute timeout
- Monitoring patterns for common AWS log groups
- 7-day retention for Lambda function logs

## Customization

### Log Group Patterns

Modify the `log_group_patterns` list in `main.tf`:

```hcl
log_group_patterns = [
  "/ecs/my-app/*",       # Specific ECS service
  "/aws/lambda/prod-*",  # Production Lambda functions only
  "application-logs-*"   # Custom application logs
]
```

### Filter Patterns

Add subscription filter patterns to capture specific log entries:

```hcl
module "firetiger_cloudwatch_logs" {
  # ... other configuration
  
  # Only capture ERROR and WARN level logs
  subscription_filter_pattern = "[time, level = ERROR || level = WARN, ...]"
}
```

## Module Source

This example uses:
```hcl
source = "github.com/firetiger-inc/public//ingest/aws/cloudwatch/logs/terraform?ref=main"
```

Pin to a specific version:
```hcl
source = "github.com/firetiger-inc/public//ingest/aws/cloudwatch/logs/terraform?ref=v1.0.0"
```

## Verification

After deployment:

1. Check the deployed resources in AWS Console
2. Monitor Lambda logs for any errors:
   ```bash
   aws logs tail /aws/lambda/my-company-logs-cloudwatch-logs-ingester --follow
   ```

## Troubleshooting

- **No logs appearing**: Check Lambda function logs for errors
- **Authentication failures**: Verify Firetiger credentials
- **Missing log groups**: Ensure patterns match existing log group names
- **Rate limiting**: Increase Lambda memory or adjust timeout

For more details, see the [main integration documentation](/ingest/aws/cloudwatch/logs/README.md).