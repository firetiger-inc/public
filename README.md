# public

This repository exposes public resources used to build on Firetiger

## Testing

The `docker-compose.yaml` file at the root of this repository can be used to
start a fully working Firetiger stack, including the ingest, compaction, and
query layers. In this mode, the storage backend is a directory on the local
file system.

The stack can be used as an OpenTelemetry collector endpoint, listening for
OTLP/GRPC and OTLP/HTTP requests on <http://localhost:4317>

The stack deploys a traefik API gateway, mimicking the Firetiger configuration
in a cloud environment, as well as a preconfigured Grafana console accessible
at <http://localhost:8321>

To start the stack:

```sh
docker pull --platform linux/amd64 public.ecr.aws/firetiger/firetiger:latest
docker compose up --detach
```

To tear down the stack:

```sh
docker compose down
```

> :warning: The current setup uses a docker image built for x86, which can run
> on MacBook laptops via the Rosetta emulation.

### Querying with Pyiceberg

The repository contains a `.pyiceberg.yaml` file with a default catalog
configured to point at the Firetiger REST catalog started by the docker compose
stack.

```sh
$ pyiceberg describe firetiger.docker.compose.logs
Table format version  2
Metadata location     s3a://storage/logs/metadata/000000004-add18f4d-ff31-4699-b423-7b1711d9fc9d.metadata.json
Table UUID            4ec860c3-aa04-4138-93b4-1e3689e7c7b5
Last Updated          1744849622179
Partition spec        [
                        1000: tenant: identity(24)
                        1001: time: hour(3)
                      ]
Sort order            [
                        3 ASC NULLS FIRST
                      ]
Current schema        Schema, id=2
                      ├── 1: resource: optional struct<12: attributes: required map<string, string>, 13: dropped_attributes_count: required int>
                      ├── 2: scope: optional struct<16: name: required string, 17: version: required string, 18: attributes: required map<string, string>, 19:
                      │   dropped_attributes_count: required int>
                      ├── 3: time: required timestamptz
                      ├── 4: severity_number: required int
                      ├── 5: severity_text: required string
                      ├── 6: body: required string
                      ├── 7: attributes: required map<string, string>
                      ├── 8: dropped_attributes_count: required int
                      ├── 9: flags: required int
                      ├── 10: trace_id: optional fixed[16]
                      ├── 11: span_id: optional fixed[8]
                      └── 24: tenant: required string
Current snapshot      Operation.APPEND: id=4, parent_id=3, schema_id=2
Snapshots             Snapshots
                      ├── Snapshot 1, schema 2: s3a://storage/logs/metadata/snap-2EF8CBF894394FDCA582C732836AB111.avro
                      ├── Snapshot 2, schema 2: s3a://storage/logs/metadata/snap-F3F5814D174846D39C076D93A3338632.avro
                      ├── Snapshot 3, schema 2: s3a://storage/logs/metadata/snap-185F83227C3347DEB1CE62425AB09650.avro
                      └── Snapshot 4, schema 2: s3a://storage/logs/metadata/snap-710F679454AC43C5AE9EC6179D038F6D.avro
Properties
```

### Querying with DuckDB

The Apache Iceberg tables backing the Firetiger stack can be queried using
the DuckDB `httpfs` and `iceberg` extensions. The following example shows how
to select all rows in the local logs table:

```sql
$ duckdb
D install https;
D install iceberg;

D load https;
D load iceberg;

D select * from iceberg_scan('http://localhost:4317/storage/logs');

┌──────────────────────┬──────────────────────┬──────────────────────┬─────────────────┬───────────────┬───┬───────┬──────────┬─────────┬─────────┐
│       resource       │        scope         │         time         │ severity_number │ severity_text │ … │ flags │ trace_id │ span_id │ tenant  │
│ struct(attributes …  │ struct("name" varc…  │ timestamp with tim…  │      int32      │    varchar    │   │ int32 │   blob   │  blob   │ varchar │
├──────────────────────┼──────────────────────┼──────────────────────┼─────────────────┼───────────────┼───┼───────┼──────────┼─────────┼─────────┤
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:26:5…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:26:5…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
│ {'attributes': {fi…  │ NULL                 │ 2025-04-16 17:27:0…  │               9 │ Info          │ … │     0 │ NULL     │ NULL    │         │
├──────────────────────┴──────────────────────┴──────────────────────┴─────────────────┴───────────────┴───┴───────┴──────────┴─────────┴─────────┤
│ 10 rows                                                                                                                    12 columns (9 shown) │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Ingest Integrations

This repository also contains cloud provider integrations for ingesting logs and events into Firetiger.

### Available Integrations
- **AWS CloudWatch Logs** (`ingest/aws/cloudwatch/logs/`) - Stream CloudWatch logs to Firetiger via Lambda and subscription filters
- **AWS ECS Events** (`ingest/aws/ecs/events/`) - Capture ECS task state changes (OOM, failures) via EventBridge

### Quick Start

```bash
# AWS CloudWatch Logs
cd ingest/aws/cloudwatch/logs/terraform
terraform init && terraform apply

# AWS ECS Events  
cd ingest/aws/ecs/events/terraform
terraform init && terraform apply
```

Each integration supports multiple deployment methods including one-click CloudFormation deployment. See the individual README files for detailed configuration options.
