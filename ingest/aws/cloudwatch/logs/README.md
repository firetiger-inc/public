# CloudWatch Logs Integration

Stream AWS CloudWatch logs to Firetiger in real-time using Lambda functions and subscription filters.

## Overview

This integration deploys:
- Lambda function to process and forward logs
- Subscription filters automatically created on matching log groups
- IAM roles and permissions
- CloudWatch log group for Lambda logs

## Project Structure

```
cloudwatch-logs/
├── src/                      # Lambda source code
│   ├── ingester.py          # Main Lambda function
│   └── filter_manager.py    # Legacy filter manager (CloudFormation only)
├── terraform/               # Terraform deployment module
├── cloudformation/          # CloudFormation deployment
├── upload.tf                # Terraform config to upload Lambda packages to S3
└── Makefile                 # Clean command only
```

## Lambda Code Distribution

The Lambda code is stored in S3 (`s3://firetiger-public/aws/ingest-cloudwatch-logs/lambda/`) and shared between Terraform and CloudFormation deployments.

### Uploading Lambda Code to S3

If you're contributing changes to the Lambda code, upload new packages using Terraform:

```bash
# Initialize and upload Lambda packages to S3
terraform init
terraform apply -target=aws_s3_object.ingester_lambda -target=aws_s3_object.filter_manager_lambda
```

**Note**: The Terraform module now manages subscription filters natively and only uses the ingester Lambda. The filter_manager Lambda is only used by the CloudFormation deployment.

## Deployment Options

### Option 1: One-Click CloudFormation Deployment

[![Deploy to AWS](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://s3.amazonaws.com/firetiger-public/aws/ingest-cloudwatch-logs/cloudformation-template.yaml&stackName=firetiger-ingest-cloudwatch-logs)

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
  --stack-name firetiger-ingest-cloudwatch-logs \
  --template-url https://s3.amazonaws.com/firetiger-public/aws/ingest-cloudwatch-logs/cloudformation-template.yaml \
  --parameters \
    ParameterKey=FiretigerEndpoint,ParameterValue=https://ingest.example.firetigerapi.com \
    ParameterKey=FiretigerUsername,ParameterValue=myuser \
    ParameterKey=FiretigerPassword,ParameterValue=mypass \
  --capabilities CAPABILITY_NAMED_IAM
```

## Multi-Region Deployment

IAM roles are global — you only need to create the Firetiger access role once per AWS account, regardless of how many regions you deploy to.

### Recommended approach: separate IAM and ingest stacks

1. **Deploy IAM role once** (any region):
   ```bash
   aws cloudformation create-stack \
     --stack-name firetiger-iam-role \
     --template-url https://s3.amazonaws.com/firetiger-public/ingest/aws/cloudwatch/logs/iam-only.yaml \
     --parameters \
       ParameterKey=FiretigerAWSAccountId,ParameterValue=<account-id> \
       ParameterKey=FiretigerExternalId,ParameterValue=<external-id> \
     --capabilities CAPABILITY_NAMED_IAM
   ```

2. **Deploy ingest stack per region**:
   ```bash
   aws cloudformation create-stack \
     --region us-west-2 \
     --stack-name firetiger-ingest-cloudwatch-logs \
     --template-url https://s3.amazonaws.com/firetiger-public/ingest/aws/cloudwatch/logs/cloudformation-template.yaml \
     --parameters \
       ParameterKey=FiretigerEndpoint,ParameterValue=https://ingest.example.firetigerapi.com \
     --capabilities CAPABILITY_NAMED_IAM
   ```
   Repeat for each region (`us-east-1`, `eu-west-1`, etc.).

### Alternative: combined template with conditional IAM

Use `ingest-and-iam-onboarding.yaml` with `CreateFiretigerAccessRole=false` for additional regions:

```bash
# First region (creates IAM role + ingest)
aws cloudformation create-stack --region us-west-2 \
  --stack-name firetiger-ingest --template-url <onboarding-url> \
  --parameters ParameterKey=FiretigerEndpoint,ParameterValue=<endpoint> \
    ParameterKey=FiretigerAWSAccountId,ParameterValue=<account-id> \
    ParameterKey=FiretigerExternalId,ParameterValue=<external-id> \
  --capabilities CAPABILITY_NAMED_IAM

# Additional regions (ingest only, skip IAM)
aws cloudformation create-stack --region eu-west-1 \
  --stack-name firetiger-ingest --template-url <onboarding-url> \
  --parameters ParameterKey=FiretigerEndpoint,ParameterValue=<endpoint> \
    ParameterKey=CreateFiretigerAccessRole,ParameterValue=false \
  --capabilities CAPABILITY_NAMED_IAM
```

### Supported regions

us-east-1, us-east-2, us-west-1, us-west-2, ca-central-1, eu-west-1, eu-west-2, eu-west-3, eu-central-1, eu-north-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, ap-northeast-2, ap-south-1, sa-east-1

## Configuration

### Required Parameters
- `firetiger_endpoint` / `FiretigerEndpoint` - Your Firetiger ingest URL

### Optional Parameters
- `firetiger_username` / `FiretigerUsername` - Basic auth username
- `firetiger_password` / `FiretigerPassword` - Basic auth password
- `log_group_patterns` / `LogGroupPatterns` - Patterns to match log groups (default: "*")
- `subscription_filter_pattern` / `SubscriptionFilterPattern` - CloudWatch filter pattern
- `lambda_timeout_seconds` / `LambdaTimeoutSeconds` - Lambda timeout in seconds (default: 300)
- `lambda_memory_size_mb` / `LambdaMemorySizeMb` - Lambda memory in MB (default: 256)
- `log_retention_days` / `LogRetentionDays` - Lambda log retention (default: 7)

## Log Group Patterns

Control which log groups are monitored:
- `*` - All log groups (default)
- `/aws/lambda/*` - Only Lambda function logs
- `my-app-*` - Log groups starting with "my-app-"

## Architecture

```
CloudWatch Log Groups
        ↓
Subscription Filters
        ↓
Lambda Function (Python 3.13)
        ↓
Firetiger Ingest API
```

## Monitoring

- Lambda function logs: `/aws/lambda/{stack-name}-cloudwatch-logs-ingester`
- Lambda metrics in CloudWatch
- Subscription filter delivery metrics

## Troubleshooting

1. **No logs appearing in Firetiger**
   - Check Lambda function logs for errors
   - Verify endpoint URL and credentials
   - Ensure log groups match patterns

2. **Lambda timeouts**
   - Increase `lambda_timeout_seconds` parameter
   - Check network connectivity to Firetiger

3. **Subscription filters not created**
   - Check IAM permissions
   - Verify log group patterns
   - Review CloudFormation/Terraform output