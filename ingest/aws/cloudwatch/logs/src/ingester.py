#!/usr/bin/env python3
"""
AWS Lambda function to ingest CloudWatch logs via Firetiger's CloudWatch API.

This function receives CloudWatch subscription filter events and forwards them
directly to the Firetiger ingest server's /cloudwatch/logs endpoint.

Uses Python 3.13 with standard library for maximum compatibility and minimal dependencies.
"""

import json
import os
import urllib.request
import urllib.parse
import urllib.error
from base64 import b64encode
from typing import Optional
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_firetiger_endpoint() -> str:
    """Get the Firetiger endpoint from environment variables."""
    endpoint = os.environ.get('FT_EXPORTER_ENDPOINT')
    if not endpoint:
        raise ValueError("FT_EXPORTER_ENDPOINT environment variable is required")
    
    # Ensure endpoint ends with /aws/cloudwatch/logs
    if not endpoint.endswith('/'):
        endpoint += '/'
    endpoint += 'aws/cloudwatch/logs'
    
    return endpoint


def get_auth_header() -> Optional[str]:
    """Get basic auth header if credentials are provided."""
    username = os.environ.get('FT_EXPORTER_BASIC_AUTH_USERNAME')
    password = os.environ.get('FT_EXPORTER_BASIC_AUTH_PASSWORD')
    
    if not username or not password:
        return None
    
    # Create basic auth header
    credentials = f"{username}:{password}"
    encoded_credentials = b64encode(credentials.encode('utf-8')).decode('ascii')
    return f"Basic {encoded_credentials}"


def post_to_firetiger(event_data: str) -> bool:
    """
    Post CloudWatch event data to Firetiger's CloudWatch logs endpoint.
    
    Args:
        event_data: The CloudWatch subscription filter event as JSON string
        
    Returns:
        True if successful, False otherwise
    """
    try:
        endpoint = get_firetiger_endpoint()
        logger.info(f"Posting CloudWatch logs to endpoint: {endpoint}")
        
        # Create request with proper headers
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Firetiger-CloudWatch-Lambda/1.0'
        }
        
        # Add authentication if configured
        auth_header = get_auth_header()
        if auth_header:
            headers['Authorization'] = auth_header
            logger.info("Using basic authentication")
        
        req = urllib.request.Request(
            endpoint,
            data=event_data.encode('utf-8'),
            headers=headers
        )
        
        # Make request with timeout
        with urllib.request.urlopen(req, timeout=30) as response:
            response_text = response.read().decode('utf-8')
            
            if response.status in [200, 202]:
                logger.info(f"Successfully sent CloudWatch logs to Firetiger (status: {response.status})")
                return True
            else:
                logger.error(f"Firetiger endpoint returned status {response.status}: {response_text}")
                return False
                
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else 'No error details'
        logger.error(f"HTTP error {e.code}: {error_body}")
        return False
    except urllib.error.URLError as e:
        logger.error(f"URL/Network error: {e.reason}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error posting to Firetiger: {e}")
        return False


def lambda_handler(event, context):
    """AWS Lambda handler function for CloudWatch log subscription events."""
    try:
        logger.info(f"Processing CloudWatch logs event for request: {context.aws_request_id}")
        
        # Log event details for debugging (without sensitive data)
        if isinstance(event, dict) and 'awslogs' in event:
            logger.info("Received CloudWatch Logs subscription event")
        elif isinstance(event, dict) and 'logGroup' in event:
            logger.info(f"Direct CloudWatch event for log group: {event.get('logGroup', 'unknown')}")
        
        # Convert event to JSON string for posting
        event_json = json.dumps(event, separators=(',', ':'))  # Compact JSON
        
        if post_to_firetiger(event_json):
            logger.info("CloudWatch logs successfully forwarded to Firetiger")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'CloudWatch logs successfully forwarded to Firetiger',
                    'requestId': context.aws_request_id
                })
            }
        else:
            logger.error("Failed to forward CloudWatch logs to Firetiger")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': 'Failed to forward CloudWatch logs to Firetiger',
                    'requestId': context.aws_request_id
                })
            }
            
    except Exception as e:
        logger.error(f"Lambda handler error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Lambda handler error: {str(e)}',
                'requestId': context.aws_request_id if context else 'unknown'
            })
        }