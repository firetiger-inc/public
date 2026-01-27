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
        # Use a 30 second timeout to avoid hanging
        with urllib.request.urlopen(req, timeout=30) as response:
            print(f"CFN response sent successfully, status code: {response.status}")
    except Exception as e:
        print(f"send_cfn_response failed: {e}")


def cleanup_subscription_filters(stack_name, context=None):
    """Delete all subscription filters created by this stack.

    Args:
        stack_name: The CloudFormation stack name used as filter prefix
        context: Lambda context for checking remaining time (optional)
    """
    if not stack_name:
        print("No stack name provided, skipping cleanup")
        return 0

    logs_client = boto3.client("logs")
    deleted_count = 0
    filter_prefix = f"firetiger-{stack_name}-"

    # Reserve 10 seconds for final logging
    min_remaining_time_ms = 10000

    try:
        # Iterate through all log groups and delete our filters
        paginator = logs_client.get_paginator("describe_log_groups")
        for page in paginator.paginate():
            for log_group in page["logGroups"]:
                # Check if we're running out of time
                if context and context.get_remaining_time_in_millis() < min_remaining_time_ms:
                    print(f"Running low on time, stopping cleanup. Deleted {deleted_count} filters so far.")
                    return deleted_count

                log_group_name = log_group["logGroupName"]
                try:
                    # Get subscription filters for this log group
                    filters_response = logs_client.describe_subscription_filters(
                        logGroupName=log_group_name
                    )
                    for sub_filter in filters_response.get("subscriptionFilters", []):
                        if sub_filter["filterName"].startswith(filter_prefix):
                            print(f"Deleting filter {sub_filter['filterName']} from {log_group_name}")
                            logs_client.delete_subscription_filter(
                                logGroupName=log_group_name,
                                filterName=sub_filter["filterName"]
                            )
                            deleted_count += 1
                except Exception as e:
                    print(f"Error processing {log_group_name}: {e}")
    except Exception as e:
        print(f"Error during cleanup: {e}")

    print(f"Deleted {deleted_count} subscription filters")
    return deleted_count


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    # Handle Delete first - send response IMMEDIATELY to avoid timeout issues
    # CloudFormation just needs to know we acknowledged the delete request
    # The cleanup can happen after the response is sent
    if event.get("RequestType") == "Delete":
        # Send SUCCESS response FIRST to prevent CloudFormation timeout
        # This ensures the stack deletion proceeds even if cleanup takes a long time
        print("Delete request received, sending SUCCESS response immediately")
        send_cfn_response(event, context, SUCCESS, {
            "Message": "Delete acknowledged, cleanup in progress"
        })

        # Now attempt cleanup (best effort - if this fails, filters are orphaned but stack deletion proceeds)
        try:
            stack_name = event.get("ResourceProperties", {}).get("StackName", "")
            if stack_name:
                deleted_count = cleanup_subscription_filters(stack_name, context)
                print(f"Cleanup completed: deleted {deleted_count} filters")
            else:
                print("No stack name provided, skipping cleanup")
        except Exception as e:
            # Log but don't fail - response already sent
            print(f"Error during cleanup (response already sent): {e}")
        return

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

        else:
            response_data = {}

        send_cfn_response(event, context, SUCCESS, response_data)

    except Exception as e:
        print(f"Error: {e}")
        send_cfn_response(event, context, FAILED, {}, str(e))