# AWS Integrations for Firetiger

This directory contains AWS-specific integrations for ingesting logs and events into Firetiger.

## Available Integrations

### 1. CloudWatch Logs (`ingest-cloudwatch-logs/`)
Stream CloudWatch logs to Firetiger in real-time using Lambda functions and subscription filters.

[![Deploy CloudWatch Logs](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/firetiger-public/aws/ingest-cloudwatch-logs/cloudformation-template.yaml&stackName=firetiger-ingest-cloudwatch-logs)

**Use Cases:**
- Application logs from EC2, ECS, Lambda
- AWS service logs (API Gateway, ALB, etc.)
- Custom application logs

**Key Features:**
- Automatic subscription filter creation
- Configurable log group patterns
- Basic authentication support
- Minimal latency

### 2. ECS Events (`ingest-ecs-events/`)
Capture ECS task state change events, particularly OutOfMemory (OOM) events, using EventBridge.

[![Deploy ECS Events](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/firetiger-public/aws/ingest-ecs-events/cloudformation-template.yaml&stackName=firetiger-ingest-ecs-events)

**Use Cases:**
- Monitor ECS task failures
- Track OOM events
- Audit task lifecycle changes

**Key Features:**
- EventBridge API Destinations (no Lambda required)
- Configurable event patterns
- Dead letter queue support
- Rate limiting

## Deployment Options

Each integration supports two deployment methods:

### CloudFormation
Traditional AWS infrastructure as code:
- Single YAML template
- AWS-native deployment
- Stack outputs for monitoring

### Terraform
Cross-platform infrastructure as code:
- Modular design
- Provider-agnostic where possible
- Reusable modules

## Authentication

All integrations support basic authentication to your Firetiger endpoint:
- Username/password for basic auth
- Credentials stored securely (CloudFormation NoEcho, Terraform sensitive)

## Common Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `firetiger_endpoint` | Your Firetiger ingest URL | ✅ |
| `firetiger_username` | Basic auth username | ❌ |
| `firetiger_password` | Basic auth password | ❌ |

## Next Steps

1. Choose an integration based on your data source
2. Select your preferred deployment method (CloudFormation or Terraform)
3. Follow the integration-specific README for detailed instructions