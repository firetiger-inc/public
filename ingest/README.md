# Firetiger Ingest Integrations

This directory contains cloud provider integrations for ingesting logs and events into Firetiger.

## Available Integrations

### AWS CloudWatch (`aws/cloudwatch/logs/`)
Stream CloudWatch logs to Firetiger in real-time using Lambda functions and subscription filters.

[![Deploy CloudWatch Logs](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/firetiger-public/ingest/aws/cloudwatch/logs/cloudformation-template.yaml&stackName=firetiger-ingest-cloudwatch-logs)

### AWS ECS (`aws/ecs/events/`)
Capture ECS task state change events, particularly OutOfMemory (OOM) events, using EventBridge.

[![Deploy ECS Events](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/firetiger-public/ingest/aws/ecs/events/cloudformation-template.yaml&stackName=firetiger-ingest-ecs-events)

## Quick Start

```bash
# AWS CloudWatch Logs
cd ingest/aws/cloudwatch/logs/terraform
terraform init && terraform apply

# AWS ECS Events  
cd ingest/aws/ecs/events/terraform
terraform init && terraform apply
```

## Structure

```
ingest/
└── aws/
    ├── cloudwatch/
    │   └── logs/           # CloudWatch Logs ingestion
    └── ecs/
        └── events/         # ECS task state change events
```

## Deployment Methods

Each integration supports multiple deployment options:
- **One-Click CloudFormation** - Deploy directly from AWS console
- **Terraform** - Cross-platform infrastructure as code
- **Manual CloudFormation** - AWS CLI deployment

## Contributing

When adding new integrations:
1. Follow the existing directory structure (`ingest/{cloud-provider}/{service}/{type}/`)
2. Support multiple deployment methods when possible
3. Include comprehensive documentation
4. Share code between deployment methods where possible