# Deploying the .NET app to Azure (OpenTofu / Terraform)

This configuration deploys the containerized .NET API to **Azure Container
Apps**, backed by an **Azure Container Registry** for the image and **Azure Key
Vault** for secrets.

## What it creates

| Resource | Purpose |
|----------|---------|
| Resource group | Container for everything below |
| Azure Container Registry (Basic) | Holds the app image; admin user disabled |
| User-assigned managed identity | Pulls from ACR and reads the Key Vault secret — no stored credentials |
| Log Analytics workspace | Container Apps logs |
| Container Apps environment | Runtime for the app |
| Key Vault (RBAC) | Stores the OTLP auth-header secret |
| Container App | Runs the image with public HTTPS ingress |

## Secret handling

The app's environment variables were reviewed (see `docker-compose.yml`). Only
one carries sensitive data:

- **`OTEL_EXPORTER_OTLP_HEADERS`** — contains `Authorization=Bearer <token>`.
  **Treated as a secret.** Stored in Key Vault (`otel-exporter-otlp-headers`)
  and injected into the Container App via a Key Vault **secret reference**
  resolved by the managed identity. The plaintext token is never set as a
  regular env var.

These are **not** secrets and are set as plain env vars: `OTEL_EXPORTER_OTLP_ENDPOINT`,
`OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_SERVICE_NAME`, `ASPNETCORE_ENVIRONMENT`.

> Note: the secret value still passes through OpenTofu state. Use a remote
> backend with encryption (e.g. an Azure Storage backend) for anything beyond
> local experimentation, and provide the secret via `TF_VAR_...` rather than a
> committed file.

## Prerequisites

- [OpenTofu](https://opentofu.org/) `>= 1.6` (or Terraform) and the Azure CLI
- `az login` completed, with rights to create the resources above and to make
  **role assignments** (Owner or User Access Administrator on the subscription)

## Configuration

All deployment inputs are **required** (there are no baked-in defaults for the
values that identify your deployment or your telemetry backend). Set them in
`terraform.tfvars` — copy `terraform.tfvars.example` as a starting point.

| Variable | Required | Description |
|----------|:--------:|-------------|
| `subscription_id` | ✅ | Azure subscription ID to deploy into |
| `location` | ✅ | Azure region for all resources (e.g. `eastus`) |
| `name_prefix` | ✅ | 2–11 chars, lowercase letters/digits, starts with a letter. Seeds globally-unique ACR/Key Vault names |
| `resource_group_name` | ✅ | Name of the resource group to create |
| `otel_exporter_otlp_endpoint` | ✅ | OTLP exporter endpoint (`OTEL_EXPORTER_OTLP_ENDPOINT`) |
| `otel_exporter_otlp_protocol` | ✅ | OTLP exporter protocol, e.g. `http/protobuf` |
| `otel_service_name` | ✅ | Service name reported in telemetry |
| `aspnetcore_environment` | ✅ | `ASPNETCORE_ENVIRONMENT`, e.g. `Production` |
| `otel_exporter_otlp_headers` | ✅ | **Secret.** OTLP headers, e.g. `Authorization=Bearer <token>`. Prefer `TF_VAR_otel_exporter_otlp_headers` |
| `container_image` | — | Optional. Fully-qualified image to deploy. Leave unset to build/push the in-repo app image |

Other knobs (`image_tag`, `image_name`, `container_cpu`, `container_memory`,
`app_port`, `min_replicas`, `max_replicas`, `tags`) keep sensible defaults and
can be overridden as needed.

## Usage

```bash
cd tofu
cp terraform.tfvars.example terraform.tfvars   # then fill in every required value
# Prefer passing the secret via the environment instead of the file:
export TF_VAR_otel_exporter_otlp_headers='Authorization=Bearer <token>'

tofu init
tofu plan
tofu apply
```

That single `apply` provisions everything **and** builds/pushes the app image —
no separate build step and no ordering to manage.

### How the image gets built

The image is built and pushed automatically during `apply` by a
`null_resource` that runs [`az acr build`](https://learn.microsoft.com/azure/container-registry/container-registry-tutorial-quick-task).
`az acr build` builds server-side on ACR's amd64 build agents, so:

- no local Docker daemon is required, and
- no `--platform` juggling is needed on Apple Silicon (Container Apps run amd64).

The Container App `depends_on` this build, so the image always exists in the
registry before the app is created or updated — this is what previously required
a manual "apply → docker build/push → apply again" dance.

The build re-runs when the image tag or the app source changes (it is triggered
by `var.image_tag` and hashes of `Dockerfile`, `DotNetApp.csproj`, and
`Program.cs`). To force a fresh image and a new revision, bump `image_tag`:

```bash
tofu apply -var image_tag=v2
```

To deploy a pre-built image from elsewhere instead of building here, set
`container_image` to a fully-qualified reference; the in-repo build is then
skipped.

### Access the app

```bash
tofu output app_url
curl "$(tofu output -raw app_url)/api/products"
```

## Clean up

```bash
tofu destroy
```
