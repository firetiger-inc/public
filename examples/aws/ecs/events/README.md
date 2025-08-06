# ECS Events Integration - Terraform Example

This example demonstrates how to deploy the Firetiger ECS Events integration using the GitHub-hosted Terraform module to capture ECS task state change events.

## Quick Start

1. Edit `main.tf` and replace `"your-password-here"` with your actual Firetiger password

2. Initialize and apply:
   ```bash
   terraform init
   terraform apply
   ```

## Configuration

The example is pre-configured to capture:
- All STOPPED tasks in the `firetiger-for-firetiger` cluster
- 20 events per second rate limit
- Dead letter queue with 1-day retention

## Event Pattern

The current configuration captures all STOPPED tasks. For complete event structure reference, see the [AWS ECS Task Events documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html).

```json
{
  "source": ["aws.ecs"],
  "detail-type": ["ECS Task State Change"],
  "detail": {
    "lastStatus": ["STOPPED"],
    "clusterArn": [
      {"suffix": ":cluster/firetiger-for-firetiger"}
    ]
  }
}
```

### Common Event Pattern Examples

#### Capture OutOfMemory Events Only
```hcl
event_pattern = jsonencode({
  source      = ["aws.ecs"]
  detail-type = ["ECS Task State Change"]
  detail = {
    lastStatus = ["STOPPED"]
    stoppedReason = [
      {"prefix": "OutOfMemoryError"},
      {"prefix": "OutOfMemory"}
    ]
  }
})
```

#### Capture All Task Failures
```hcl
event_pattern = jsonencode({
  source      = ["aws.ecs"]
  detail-type = ["ECS Task State Change"]
  detail = {
    lastStatus = ["STOPPED"]
    stoppedReason = [
      {"anything-but": ["Scaling activity initiated by (deployment ecs-svc/*)"]}
    ]
  }
})
```

#### Capture Service Deployment Failures
```hcl
event_pattern = jsonencode({
  source      = ["aws.ecs"]
  detail-type = ["ECS Deployment State Change"]
  detail = {
    eventName = ["SERVICE_DEPLOYMENT_FAILED"]
  }
})
```

## Module Source

This example uses:
```hcl
source = "github.com/firetiger-inc/public//ingest/aws/ecs/events/terraform?ref=main"
```

Pin to a specific version:
```hcl
source = "github.com/firetiger-inc/public//ingest/aws/ecs/events/terraform?ref=v1.0.0"
```

## Verification

After deployment:

1. Check the deployed resources in AWS Console
2. Monitor EventBridge metrics:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Events \
     --metric-name SuccessfulRuleMatches \
     --dimensions Name=Rule,Value=firetiger-ecs-task-stopped-events \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Sum
   ```

3. Check dead letter queue for failures:
   ```bash
   aws sqs get-queue-attributes \
     --queue-url https://sqs.us-east-1.amazonaws.com/YOUR-ACCOUNT/firetiger-for-firetiger-eventbridge-ecs-dlq \
     --attribute-names ApproximateNumberOfMessages
   ```

## Testing

Generate a test event to verify the integration:

```bash
# Stop a test task to generate an event
aws ecs stop-task \
  --cluster firetiger-for-firetiger \
  --task <task-arn> \
  --reason "Testing Firetiger integration"
```

## Troubleshooting

- **No events captured**: Verify event pattern matches your ECS events
- **Authentication failures**: Check Firetiger credentials
- **Events in DLQ**: Review CloudWatch Logs for API destination errors
- **Rate limiting**: Adjust `invocation_rate_per_second` based on volume

For more details, see the [main integration documentation](/ingest/aws/ecs/events/README.md).