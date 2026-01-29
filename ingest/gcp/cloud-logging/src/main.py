"""
GCP Cloud Function (2nd gen) to ingest Cloud Logging entries via Firetiger's OTLP endpoint.

This function receives Pub/Sub-triggered events containing Cloud Logging LogEntry JSON,
converts them to OTLP log format, and forwards them to Firetiger's OTEL HTTP endpoint.

Uses Python standard library for HTTP to minimize cold start time.
"""

import json
import os
import urllib.request
import urllib.error
from base64 import b64encode
import logging
import time

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Cloud Logging severity to OTLP severity number mapping
# https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogSeverity
# https://opentelemetry.io/docs/specs/otel/logs/data-model/#severity-fields
SEVERITY_MAP = {
    "DEFAULT": 0,
    "DEBUG": 5,
    "INFO": 9,
    "NOTICE": 10,
    "WARNING": 13,
    "ERROR": 17,
    "CRITICAL": 21,
    "ALERT": 22,
    "EMERGENCY": 24,
}


def get_firetiger_endpoint():
    """Get the Firetiger OTLP endpoint from environment variables."""
    endpoint = os.environ.get("FT_EXPORTER_ENDPOINT")
    if not endpoint:
        raise ValueError("FT_EXPORTER_ENDPOINT environment variable is required")

    if endpoint.endswith("/"):
        endpoint = endpoint[:-1]
    return endpoint + "/v1/logs"


def get_auth_header():
    """Get basic auth header if credentials are provided."""
    username = os.environ.get("FT_EXPORTER_BASIC_AUTH_USERNAME")
    password = os.environ.get("FT_EXPORTER_BASIC_AUTH_PASSWORD")

    if not username or not password:
        return None

    credentials = username + ":" + password
    encoded = b64encode(credentials.encode("utf-8")).decode("ascii")
    return "Basic " + encoded


def log_entry_to_otlp(log_entry):
    """Convert a Cloud Logging LogEntry to an OTLP LogRecord.

    Args:
        log_entry: dict, the Cloud Logging LogEntry JSON

    Returns:
        dict, an OTLP ResourceLogs structure
    """
    severity_text = log_entry.get("severity", "DEFAULT")
    severity_number = SEVERITY_MAP.get(severity_text, 0)

    # Extract timestamp (Cloud Logging uses RFC3339)
    timestamp = log_entry.get("timestamp", "")
    time_unix_nano = 0
    if timestamp:
        try:
            # Parse RFC3339 timestamp to nanoseconds
            # Handle both "Z" suffix and "+00:00" offset
            ts = timestamp.replace("Z", "+00:00")
            # Remove the timezone offset for parsing
            if "+" in ts:
                ts_parts = ts.rsplit("+", 1)
                ts = ts_parts[0]
            elif ts.count("-") > 2:
                ts_parts = ts.rsplit("-", 1)
                ts = ts_parts[0]

            # Parse date and time parts
            date_time = ts.split("T")
            if len(date_time) == 2:
                date_parts = date_time[0].split("-")
                time_parts = date_time[1].split(":")
                if len(date_parts) == 3 and len(time_parts) >= 2:
                    import calendar
                    import datetime

                    # Handle fractional seconds
                    seconds_str = time_parts[2] if len(time_parts) > 2 else "0"
                    if "." in seconds_str:
                        sec_parts = seconds_str.split(".")
                        whole_seconds = int(sec_parts[0])
                        frac = sec_parts[1][:9].ljust(9, "0")
                        frac_nanos = int(frac)
                    else:
                        whole_seconds = int(seconds_str)
                        frac_nanos = 0

                    dt = datetime.datetime(
                        int(date_parts[0]),
                        int(date_parts[1]),
                        int(date_parts[2]),
                        int(time_parts[0]),
                        int(time_parts[1]),
                        whole_seconds,
                        tzinfo=datetime.timezone.utc,
                    )
                    time_unix_nano = int(calendar.timegm(dt.timetuple())) * 1_000_000_000 + frac_nanos
        except (ValueError, IndexError, OverflowError):
            time_unix_nano = int(time.time() * 1_000_000_000)

    # Build body from payload
    payload = log_entry.get("textPayload")
    if payload is None:
        json_payload = log_entry.get("jsonPayload")
        if json_payload is not None:
            payload = json.dumps(json_payload, separators=(",", ":"))
        else:
            proto_payload = log_entry.get("protoPayload")
            if proto_payload is not None:
                payload = json.dumps(proto_payload, separators=(",", ":"))
            else:
                payload = ""

    # Build attributes from labels and resource
    attributes = []
    labels = log_entry.get("labels", {})
    for key, value in labels.items():
        attributes.append({
            "key": "gcp.label." + key,
            "value": {"stringValue": str(value)},
        })

    resource_labels = log_entry.get("resource", {}).get("labels", {})
    for key, value in resource_labels.items():
        attributes.append({
            "key": "gcp.resource.label." + key,
            "value": {"stringValue": str(value)},
        })

    resource_type = log_entry.get("resource", {}).get("type", "")
    if resource_type:
        attributes.append({
            "key": "gcp.resource.type",
            "value": {"stringValue": resource_type},
        })

    log_name = log_entry.get("logName", "")
    if log_name:
        attributes.append({
            "key": "gcp.log_name",
            "value": {"stringValue": log_name},
        })

    insert_id = log_entry.get("insertId", "")
    if insert_id:
        attributes.append({
            "key": "gcp.insert_id",
            "value": {"stringValue": insert_id},
        })

    trace = log_entry.get("trace", "")
    if trace:
        attributes.append({
            "key": "gcp.trace",
            "value": {"stringValue": trace},
        })

    span_id = log_entry.get("spanId", "")
    if span_id:
        attributes.append({
            "key": "gcp.span_id",
            "value": {"stringValue": span_id},
        })

    # Build resource attributes
    resource_attributes = [
        {
            "key": "cloud.provider",
            "value": {"stringValue": "gcp"},
        },
    ]

    project_id = log_entry.get("resource", {}).get("labels", {}).get("project_id", "")
    if project_id:
        resource_attributes.append({
            "key": "cloud.account.id",
            "value": {"stringValue": project_id},
        })

    if resource_type:
        resource_attributes.append({
            "key": "gcp.resource_type",
            "value": {"stringValue": resource_type},
        })

    log_record = {
        "timeUnixNano": str(time_unix_nano),
        "severityNumber": severity_number,
        "severityText": severity_text,
        "body": {"stringValue": payload},
        "attributes": attributes,
    }

    return {
        "resourceLogs": [
            {
                "resource": {"attributes": resource_attributes},
                "scopeLogs": [
                    {
                        "scope": {"name": "firetiger-gcp-cloud-logging"},
                        "logRecords": [log_record],
                    }
                ],
            }
        ]
    }


def post_to_firetiger(otlp_payload):
    """Post OTLP log payload to Firetiger endpoint.

    Args:
        otlp_payload: dict, the OTLP ResourceLogs JSON

    Returns:
        True if successful, False otherwise
    """
    try:
        endpoint = get_firetiger_endpoint()
        data = json.dumps(otlp_payload, separators=(",", ":")).encode("utf-8")

        headers = {
            "Content-Type": "application/json",
            "User-Agent": "Firetiger-GCP-CloudFunction/1.0",
        }

        auth_header = get_auth_header()
        if auth_header:
            headers["Authorization"] = auth_header

        req = urllib.request.Request(endpoint, data=data, headers=headers)

        with urllib.request.urlopen(req, timeout=30) as response:
            if response.status in (200, 202):
                logger.info("Successfully sent logs to Firetiger (status: %d)", response.status)
                return True
            response_text = response.read().decode("utf-8")
            logger.error("Firetiger endpoint returned status %d: %s", response.status, response_text)
            return False

    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else "No error details"
        logger.error("HTTP error %d: %s", e.code, error_body)
        return False
    except urllib.error.URLError as e:
        logger.error("URL/Network error: %s", e.reason)
        return False
    except Exception as e:
        logger.error("Unexpected error posting to Firetiger: %s", e)
        return False


def process_log_entry(cloud_event):
    """Cloud Function entry point for Pub/Sub-triggered Cloud Logging events.

    Args:
        cloud_event: CloudEvent containing the Pub/Sub message with a LogEntry
    """
    import base64

    try:
        # Extract the Pub/Sub message data
        pubsub_message = cloud_event.data.get("message", {})
        message_data = pubsub_message.get("data", "")

        if not message_data:
            logger.warning("Received empty Pub/Sub message")
            return

        # Decode base64-encoded log entry
        decoded = base64.b64decode(message_data).decode("utf-8")
        log_entry = json.loads(decoded)

        # Convert to OTLP format
        otlp_payload = log_entry_to_otlp(log_entry)

        # Send to Firetiger
        if post_to_firetiger(otlp_payload):
            logger.info("Cloud Logging entry forwarded to Firetiger")
        else:
            logger.error("Failed to forward Cloud Logging entry to Firetiger")

    except Exception as e:
        logger.error("Error processing Cloud Logging entry: %s", e)
        raise
