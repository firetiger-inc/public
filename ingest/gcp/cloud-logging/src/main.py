"""
GCP Cloud Function (2nd gen) to relay Cloud Logging entries to Firetiger.

This function receives Pub/Sub-triggered events containing Cloud Logging LogEntry JSON
and forwards the raw JSON to Firetiger's /gcp/cloud-logging endpoint, which handles
all parsing, routing, and schema logic.

Uses Python standard library for HTTP to minimize cold start time.
"""

import os
import urllib.request
from base64 import b64encode

import functions_framework


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

    # No logging here - any logs would go to Cloud Logging and create a feedback loop.
    # Exceptions propagate to GCP Cloud Functions runtime which handles retries.
    with urllib.request.urlopen(req, timeout=30) as response:
        pass  # Success - 2xx responses. Non-2xx raises HTTPError.
