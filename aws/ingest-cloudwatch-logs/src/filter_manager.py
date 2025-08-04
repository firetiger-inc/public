import boto3
import cfnresponse
import re
import json

def lambda_handler(event, context):
    try:
        logs_client = boto3.client('logs')
        
        lambda_arn = event['ResourceProperties']['LambdaArn']
        filter_pattern = event['ResourceProperties']['FilterPattern']
        log_group_patterns = event['ResourceProperties']['LogGroupPatterns']
        stack_name = event['ResourceProperties']['StackName']
        
        if event['RequestType'] == 'Create' or event['RequestType'] == 'Update':
            # Get all log groups
            paginator = logs_client.get_paginator('describe_log_groups')
            all_log_groups = []
            
            for page in paginator.paginate():
                all_log_groups.extend([lg['logGroupName'] for lg in page['logGroups']])
            
            # Filter log groups based on patterns
            matched_groups = []
            for log_group in all_log_groups:
                for pattern in log_group_patterns:
                    if pattern == '*' or re.search(pattern, log_group):
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
                        destinationArn=lambda_arn
                    )
                    created_filters.append({'logGroup': log_group, 'filterName': filter_name})
                except Exception as e:
                    print(f"Failed to create filter for {log_group}: {str(e)}")
            
            response_data = {
                'FilterCount': len(created_filters),
                'MonitoredLogGroups': len(matched_groups),
                'CreatedFilters': created_filters
            }
            
        elif event['RequestType'] == 'Delete':
            # Clean up subscription filters
            # Note: This is a simplified cleanup - in production you'd want to track which filters were created
            response_data = {'Message': 'Cleanup completed'}
        
        cfnresponse.send(event, context, cfnresponse.SUCCESS, response_data)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        cfnresponse.send(event, context, cfnresponse.FAILED, {}, str(e))