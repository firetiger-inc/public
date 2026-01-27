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


def cleanup_subscription_filters(stack_name):
    """Delete all subscription filters created by this stack."""
    if not stack_name:
        print("No stack name provided, skipping cleanup")
        return 0

    logs_client = boto3.client("logs")
    deleted_count = 0
    filter_prefix = f"firetiger-{stack_name}-"

    try:
        # Iterate through all log groups and delete our filters
        paginator = logs_client.get_paginator("describe_log_groups")
        for page in paginator.paginate():
            for log_group in page["logGroups"]:
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

    # Handle Delete first with its own try/catch - MUST always send response
    if event["RequestType"] == "Delete":
        try:
            stack_name = event.get("ResourceProperties", {}).get("StackName", "")
            deleted_count = cleanup_subscription_filters(stack_name)
            send_cfn_response(event, context, SUCCESS, {
                "Message": "Cleanup completed",
                "DeletedFilters": deleted_count
            })
        except Exception as e:
            print(f"Error during delete (still sending SUCCESS to avoid stuck stack): {e}")
            # Always send SUCCESS for delete to prevent stuck stacks
            # The filters will be orphaned but can be manually cleaned up
            send_cfn_response(event, context, SUCCESS, {
                "Message": "Cleanup completed with errors",
                "Error": str(e)
            })
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
            }

        else:
            response_data = {}

        send_cfn_response(event, context, SUCCESS, response_data)

    except Exception as e:
        print(f"Error: {e}")
        send_cfn_response(event, context, FAILED, {}, str(e))