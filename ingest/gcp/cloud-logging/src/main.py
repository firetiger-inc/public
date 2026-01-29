"""
GCP Cloud Function (2nd gen) to ingest Cloud Logging entries via Firetiger's OTLP endpoint.

This function receives Pub/Sub-triggered events containing Cloud Logging LogEntry JSON,
converts them to OTLP log format, and forwards them to Firetiger's OTEL HTTP endpoint.

Uses Python standard library for HTTP to minimize cold start time.
"""

import json
import os
import urllib.parse
import urllib.request
import urllib.error
from base64 import b64encode
import logging
import time

import functions_framework

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
            import datetime

            # Parse RFC3339 timestamp preserving timezone offset
            ts = timestamp.replace("Z", "+00:00")
            dt = datetime.datetime.fromisoformat(ts)

            # Extract fractional seconds as nanoseconds before converting
            frac_str = ""
            # fromisoformat handles up to 6 fractional digits (microseconds);
            # extract raw nanosecond fraction from the original string for full precision
            t_part = ts.split("T")[1] if "T" in ts else ""
            dot_pos = t_part.find(".")
            if dot_pos >= 0:
                # Grab digits between '.' and the timezone offset (+/-)
                after_dot = t_part[dot_pos + 1:]
                frac_digits = ""
                for ch in after_dot:
                    if ch.isdigit():
                        frac_digits += ch
                    else:
                        break
                frac_str = frac_digits[:9].ljust(9, "0")

            frac_nanos = int(frac_str) if frac_str else 0

            # Convert to UTC epoch seconds (handles timezone offsets correctly)
            epoch = int(dt.timestamp())
            # dt.timestamp() includes microseconds; use only whole seconds + raw nanos
            time_unix_nano = epoch * 1_000_000_000 + frac_nanos
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

    trace_sampled = log_entry.get("traceSampled")
    if trace_sampled is not None:
        attributes.append({
            "key": "gcp.trace_sampled",
            "value": {"boolValue": trace_sampled},
        })

    receive_timestamp = log_entry.get("receiveTimestamp", "")
    if receive_timestamp:
        attributes.append({
            "key": "gcp.receive_timestamp",
            "value": {"stringValue": receive_timestamp},
        })

    # Operation metadata (correlates related log entries)
    operation = log_entry.get("operation")
    if operation:
        op_id = operation.get("id", "")
        if op_id:
            attributes.append({
                "key": "gcp.operation.id",
                "value": {"stringValue": op_id},
            })
        op_producer = operation.get("producer", "")
        if op_producer:
            attributes.append({
                "key": "gcp.operation.producer",
                "value": {"stringValue": op_producer},
            })
        if operation.get("first"):
            attributes.append({
                "key": "gcp.operation.first",
                "value": {"boolValue": True},
            })
        if operation.get("last"):
            attributes.append({
                "key": "gcp.operation.last",
                "value": {"boolValue": True},
            })

    # Source location (file, line, function)
    source_location = log_entry.get("sourceLocation")
    if source_location:
        sl_file = source_location.get("file", "")
        if sl_file:
            attributes.append({
                "key": "code.filepath",
                "value": {"stringValue": sl_file},
            })
        sl_line = source_location.get("line")
        if sl_line:
            attributes.append({
                "key": "code.lineno",
                "value": {"intValue": str(sl_line)},
            })
        sl_function = source_location.get("function", "")
        if sl_function:
            attributes.append({
                "key": "code.function",
                "value": {"stringValue": sl_function},
            })

    # HTTP request details
    http_request = log_entry.get("httpRequest")
    if http_request:
        http_fields = [
            ("http.request.method", "requestMethod", "stringValue"),
            ("url.full", "requestUrl", "stringValue"),
            ("http.response.status_code", "status", "intValue"),
            ("user_agent.original", "userAgent", "stringValue"),
            ("client.address", "remoteIp", "stringValue"),
            ("server.address", "serverIp", "stringValue"),
            ("http.request.header.referer", "referer", "stringValue"),
            ("network.protocol.name", "protocol", "stringValue"),
        ]
        for attr_key, json_key, value_type in http_fields:
            val = http_request.get(json_key)
            if val:
                attributes.append({
                    "key": attr_key,
                    "value": {value_type: str(val) if value_type == "intValue" else val},
                })

        int_fields = [
            ("http.request.body.size", "requestSize"),
            ("http.response.body.size", "responseSize"),
        ]
        for attr_key, json_key in int_fields:
            val = http_request.get(json_key)
            if val:
                attributes.append({
                    "key": attr_key,
                    "value": {"intValue": str(val)},
                })

        latency = http_request.get("latency")
        if latency:
            # Latency comes as a Duration string like "0.123456s"
            latency_str = str(latency)
            if latency_str.endswith("s"):
                latency_str = latency_str[:-1]
            try:
                latency_ms = float(latency_str) * 1000
                attributes.append({
                    "key": "http.request.duration_ms",
                    "value": {"doubleValue": latency_ms},
                })
            except ValueError:
                pass

        cache_fields = [
            ("gcp.http.cache_lookup", "cacheLookup"),
            ("gcp.http.cache_hit", "cacheHit"),
            ("gcp.http.cache_validated_with_origin_server", "cacheValidatedWithOriginServer"),
        ]
        for attr_key, json_key in cache_fields:
            val = http_request.get(json_key)
            if val is not None:
                attributes.append({
                    "key": attr_key,
                    "value": {"boolValue": val},
                })

        cache_fill = http_request.get("cacheFillBytes")
        if cache_fill:
            attributes.append({
                "key": "gcp.http.cache_fill_bytes",
                "value": {"intValue": str(cache_fill)},
            })

    # Derive service.name from logName to match Go ingest routing
    # Go code: url.PathUnescape(logName), prefix "gcp/", append "/http-requests" for HTTP logs
    service_name = "gcp"
    if log_name:
        decoded_log_name = urllib.parse.unquote(log_name).strip("/")
        if decoded_log_name:
            service_name = "gcp/" + decoded_log_name
            if log_entry.get("httpRequest"):
                service_name += "/http-requests"

    # Build resource attributes
    resource_attributes = [
        {
            "key": "service.name",
            "value": {"stringValue": service_name},
        },
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


@functions_framework.cloud_event
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
