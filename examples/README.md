# Firetiger Integration Examples

This directory contains example configurations for deploying Firetiger integrations using the GitHub-hosted modules.

## Directory Structure

The examples follow the same structure as the main `ingest/` directory:

```
examples/
└── aws/
    ├── cloudwatch/
    │   └── logs/           # CloudWatch Logs integration example
    └── ecs/
        └── events/         # ECS Events integration example
```

## Available Examples

### AWS Integrations

- **[CloudWatch Logs](aws/cloudwatch/logs/)** - Ingest CloudWatch logs using Lambda and subscription filters
- **[ECS Events](aws/ecs/events/)** - Capture ECS task state changes via EventBridge

## Using the Examples

Each example directory contains:
- `main.tf` - Complete Terraform configuration with hard-coded values
- `README.md` - Specific documentation and customization options

### General Steps

1. Navigate to the example directory:
   ```bash
   cd examples/aws/cloudwatch/logs
   # or
   cd examples/aws/ecs/events
   ```

2. Edit `main.tf` and replace `"your-password-here"` with your actual Firetiger password

3. Deploy:
   ```bash
   terraform init
   terraform apply
   ```

## Module Sources

All examples use the official GitHub-hosted modules:

```hcl
# CloudWatch Logs
source = "github.com/firetiger-inc/public//ingest/aws/cloudwatch/logs/terraform?ref=main"

# ECS Events
source = "github.com/firetiger-inc/public//ingest/aws/ecs/events/terraform?ref=main"
```

## Security Notes

- Replace `"your-password-here"` with your actual password before deploying
- Never commit files containing actual passwords to version control
- Use AWS Secrets Manager or Parameter Store for production deployments
- Consider using environment variables for sensitive values

## Contributing

To add new examples:
1. Follow the existing directory structure
2. Include a complete, working configuration
3. Provide clear documentation
4. Add appropriate `.gitignore` entries

## Support

For questions or issues:
- Check individual example READMEs
- Review the main [integration documentation](/ingest/)
- Contact Firetiger support