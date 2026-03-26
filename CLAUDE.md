# CLAUDE.md

## Repo overview

Public resources for Firetiger — cloud integrations, connection specs, examples, and local dev tooling.

## Modules

- **connections/** — Terraform module that uploads curated OpenAPI specs (e.g. Vanta, WorkOS) to `s3://firetiger-public`. Add a new connection by creating a `<name>/openapi.json` dir and adding the name to `locals.connections` in `upload.tf`. Apply from `connections/`.

- **ingest/aws/cloudwatch/logs/** — Lambda-based integration that streams CloudWatch logs into Firetiger via subscription filters. Deployable via CloudFormation (`cloudformation/template.yaml`) or Terraform (`terraform/`). `upload.tf` uploads the Lambda zip to S3.

- **ingest/aws/ecs/events/** — EventBridge integration that captures ECS task state changes (OOM, failures). Deployable via CloudFormation or Terraform. `upload.tf` uploads artifacts to S3.

- **ingest/gcp/cloud-logging/** — Cloud Function integration for ingesting GCP Cloud Logging into Firetiger. `upload.tf` uploads function code to S3.

- **examples/** — Reference Terraform configs showing how to deploy each ingest integration. Uses GitHub-hosted modules (e.g. `source = "github.com/firetiger-inc/public//ingest/aws/cloudwatch/logs/terraform?ref=main"`).

- **iceberg/table_metadata/** — Terraform module that generates Apache Iceberg v2 table metadata JSON. Used by Firetiger's query/storage layer.

## Local dev

`docker-compose.yaml` runs the full Firetiger stack locally (ingest, compaction, query, Grafana on `:8321`, OTLP on `:4317`).
