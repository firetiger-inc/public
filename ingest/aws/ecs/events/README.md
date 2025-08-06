# ECS Events Integration

Capture AWS ECS task state change events and send them to Firetiger using EventBridge API Destinations.

## Overview

This integration deploys:

- EventBridge rule with configurable event patterns
- API Destination pointing to Firetiger
- EventBridge connection for authentication
- Optional dead letter queue for failed events
- IAM roles and permissions

## Deployment Options

### Option 1: One-Click CloudFormation Deployment

[![Deploy to AWS](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/firetiger-public/aws/ingest-ecs-events/cloudformation-template.yaml&stackName=firetiger-ingest-ecs-events)

Click the button above to deploy directly to your AWS account. You'll need to provide:

- **FiretigerEndpoint**: Your Firetiger ingest URL
- **FiretigerUsername**: Basic auth username (optional)
- **FiretigerPassword**: Basic auth password (optional)

### Option 2: Terraform

```bash
cd terraform/
terraform init
terraform apply \
  -var="firetiger_endpoint=https://ingest.example.firetigerapi.com" \
  -var="firetiger_username=myuser" \
  -var="firetiger_password=mypass"
```

### Option 3: Manual CloudFormation

```bash
aws cloudformation create-stack \
  --stack-name firetiger-ingest-ecs-events \
  --template-url https://s3.amazonaws.com/firetiger-public/aws/ingest-ecs-events/cloudformation-template.yaml \
  --parameters \
    ParameterKey=FiretigerEndpoint,ParameterValue=https://ingest.example.firetigerapi.com \
    ParameterKey=FiretigerUsername,ParameterValue=myuser \
    ParameterKey=FiretigerPassword,ParameterValue=mypass \
  --capabilities CAPABILITY_NAMED_IAM
```

## Configuration

### Required Parameters

- `firetiger_endpoint` / `FiretigerEndpoint` - Your Firetiger ingest URL

### Optional Parameters

- `firetiger_username` / `FiretigerUsername` - Basic auth username
- `firetiger_password` / `FiretigerPassword` - Basic auth password
- `event_pattern` / `EventPattern` - EventBridge rule pattern (default: STOPPED tasks)
- `invocation_rate_per_second` / `InvocationRatePerSecond` - Rate limit (default: 1)
- `enable_dead_letter_queue` / `EnableDeadLetterQueue` - Enable DLQ (default: true)

## Event Patterns

For complete event structure reference, see the [AWS ECS Task Events documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html).

### Default (STOPPED Tasks)

```json
{
  "source": ["aws.ecs"],
  "detail-type": ["ECS Task State Change"],
  "detail": {
    "lastStatus": ["STOPPED"]
  }
}
```

### OOM Events Only

```json
{
  "source": ["aws.ecs"],
  "detail-type": ["ECS Task State Change"],
  "detail": {
    "lastStatus": ["STOPPED"],
    "stoppedReason": [
      { "prefix": "OutOfMemoryError" },
      { "prefix": "OutOfMemory" }
    ]
  }
}
```

### All Task State Changes

```json
{
  "source": ["aws.ecs"],
  "detail-type": ["ECS Task State Change"]
}
```

## Architecture

```
ECS Task State Changes
        ↓
EventBridge Rule
        ↓
API Destination
        ↓
Firetiger Ingest API
        ↓ (on failure)
Dead Letter Queue (SQS)
```

## Monitoring

- EventBridge rule metrics in CloudWatch
- API Destination invocation metrics
- Dead letter queue messages (if enabled)
- CloudWatch Logs: `/aws/events/rule/{rule-name}`

## Troubleshooting

1. **HTTP 401 Unauthorized**
   - Verify username and password
   - Check EventBridge connection configuration

2. **Events not appearing**
   - Check EventBridge rule metrics
   - Verify event pattern matches your events
   - Review dead letter queue

3. **Rate limiting**
   - Increase `invocation_rate_per_second`
   - Monitor API Destination throttling metrics

