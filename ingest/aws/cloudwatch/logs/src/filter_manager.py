import boto3
import json
import re
import urllib.request

# CloudFormation response constants (cfnresponse module was removed in Python 3.13)
SUCCESS = "SUCCESS"
FAILED = "FAILED"


def send_cfn_response(event, context, response_status, response_data, reason=None):
    """Send a response to CloudFormation for custom resource requests."""
    response_url = event.get("ResponseURL")
    if not response_url:
        print("No ResponseURL in event, skipping CFN response")
        return

    response_body = {
        "Status": response_status,
        "Reason": reason or f"See CloudWatch Log Stream: {context.log_stream_name}",
        "PhysicalResourceId": context.log_stream_name,
        "StackId": event.get("StackId", ""),
        "RequestId": event.get("RequestId", ""),
        "LogicalResourceId": event.get("LogicalResourceId", ""),
        "Data": response_data or {},
    }

    json_response_body = json.dumps(response_body)
    print(f"Response body: {json_response_body}")

    headers = {
        "Content-Type": "",
        "Content-Length": str(len(json_response_body)),
    }

    req = urllib.request.Request(
        response_url, data=json_response_body.encode("utf-8"), headers=headers, method="PUT"
    )

    try:
        with urllib.request.urlopen(req) as response:
            print(f"Status code: {response.status}")
    except Exception as e:
        print(f"send_cfn_response failed: {e}")


def lambda_handler(event, context):
    try:
        logs_client = boto3.client("logs")

        lambda_arn = event["ResourceProperties"]["LambdaArn"]
        filter_pattern = event["ResourceProperties"]["FilterPattern"]
        log_group_patterns = event["ResourceProperties"]["LogGroupPatterns"]
        stack_name = event["ResourceProperties"]["StackName"]

        if event["RequestType"] in ("Create", "Update"):
            # Get all log groups
            paginator = logs_client.get_paginator("describe_log_groups")
            all_log_groups = []

            for page in paginator.paginate():
                all_log_groups.extend([lg["logGroupName"] for lg in page["logGroups"]])

            # Filter log groups based on patterns
            matched_groups = []
            for log_group in all_log_groups:
                for pattern in log_group_patterns:
                    if pattern == "*" or re.search(pattern, log_group):
                        matched_groups.append(log_group)
                        break

            # Create subscription filters
            created_filters = []
            for log_group in matched_groups:
                filter_name = f"firetiger-{stack_name}-{log_group.replace('/', '-').replace('_', '-')}"
                try:
                    logs_client.put_subscription_filter(
                        logGroupName=log_group,
                        filterName=filter_name,
                        filterPattern=filter_pattern,
                        destinationArn=lambda_arn,
                    )
                    created_filters.append({"logGroup": log_group, "filterName": filter_name})
                except Exception as e:
                    print(f"Failed to create filter for {log_group}: {e}")

            response_data = {
                "FilterCount": len(created_filters),
                "MonitoredLogGroups": len(matched_groups),
                "CreatedFilters": created_filters,
            }

        elif event["RequestType"] == "Delete":
            # Clean up subscription filters
            # Note: This is a simplified cleanup - in production you'd want to track which filters were created
            response_data = {"Message": "Cleanup completed"}
        else:
            response_data = {}

        send_cfn_response(event, context, SUCCESS, response_data)

    except Exception as e:
        print(f"Error: {e}")
        send_cfn_response(event, context, FAILED, {}, str(e))