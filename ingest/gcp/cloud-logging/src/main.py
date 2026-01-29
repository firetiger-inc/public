"""
GCP Cloud Function (2nd gen) to relay Cloud Logging entries to Firetiger.

This function receives Pub/Sub-triggered events containing Cloud Logging LogEntry JSON
and forwards the raw JSON to Firetiger's /gcp/cloud-logging endpoint, which handles
all parsing, routing, and schema logic.

Uses Python standard library for HTTP to minimize cold start time.
"""

import os
import urllib.request
import urllib.error
from base64 import b64encode
import logging

import functions_framework

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def get_firetiger_endpoint():
    endpoint = os.environ.get("FT_EXPORTER_ENDPOINT")
    if not endpoint:
        raise ValueError("FT_EXPORTER_ENDPOINT environment variable is required")

    if endpoint.endswith("/"):
        endpoint = endpoint[:-1]
    return endpoint + "/gcp/cloud-logging"


def get_auth_header():
    username = os.environ.get("FT_EXPORTER_BASIC_AUTH_USERNAME")
    password = os.environ.get("FT_EXPORTER_BASIC_AUTH_PASSWORD")

    if not username or not password:
        return None

    credentials = username + ":" + password
    encoded = b64encode(credentials.encode("utf-8")).decode("ascii")
    return "Basic " + encoded


@functions_framework.cloud_event
def process_log_entry(cloud_event):
    """Cloud Function entry point for Pub/Sub-triggered Cloud Logging events.

    Decodes the base64 Pub/Sub message (raw LogEntry JSON) and forwards it
    directly to Firetiger's /gcp/cloud-logging endpoint.
    """
    import base64

    pubsub_message = cloud_event.data.get("message", {})
    message_data = pubsub_message.get("data", "")

    if not message_data:
        logger.warning("Received empty Pub/Sub message")
        return

    log_entry_json = base64.b64decode(message_data)

    endpoint = get_firetiger_endpoint()
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Firetiger-GCP-CloudFunction/1.0",
    }

    auth_header = get_auth_header()
    if auth_header:
        headers["Authorization"] = auth_header

    req = urllib.request.Request(endpoint, data=log_entry_json, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            if response.status in (200, 202):
                logger.info("Forwarded log entry to Firetiger (status: %d)", response.status)
            else:
                response_text = response.read().decode("utf-8")
                logger.error("Firetiger returned status %d: %s", response.status, response_text)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else "No error details"
        logger.error("HTTP error %d: %s", e.code, error_body)
        raise
    except urllib.error.URLError as e:
        logger.error("URL/Network error: %s", e.reason)
        raise
