# public
This repository exposes public resources used to build on Firetiger

## Testing

The `docker-compose.yaml` file at the root of this repository can be used to
start a fully working Firetiger stack, including the ingest, compaction, and
query layers. In this mode, the storage backend is a directory on the local
file system.

The stack can be used as an OpenTelemetry collector endpoint, listening for
OTLP/GRPC and OTLP/HTTP requests on http://localhost:4317

The stack deploys a traefik API gateway, mimicking the Firetiger configuration
in a cloud environment, as well as a preconfigured Grafana console accessible
at http://localhost:8321

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

## Deployment

- [**AWS**](./aws/configuration/README.md)
- [**GCP**](./gcp/configuration/README.md)
