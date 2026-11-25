# DotNetApp

This project is an updated version of a repository by jangolano used for a talk at a conference.  
I added pyroscope as an exercise to learn more about how OTEL works.  
See original: https://github.com/jangolano/dot-net-otel-example  

A minimal ASP.NET Core Web API for managing a product catalog. It uses a layered
architecture (controller → service → repository) backed by an Entity Framework Core
in-memory database, seeded with sample data on startup.

## Tech Stack

- .NET 10 (`net10.0`)
- ASP.NET Core Web API (controllers)
- Entity Framework Core with the in-memory provider (`Microsoft.EntityFrameworkCore.InMemory`)
- OpenAPI via `Microsoft.AspNetCore.OpenApi`

## Project Structure

```
Controllers/    REST endpoints (ProductsController)
Services/       Business logic layer (IProductService / ProductService)
Repositories/   Data access layer (IProductRepository / ProductRepository)
Data/           EF Core DbContext (AppDbContext) and seed data
Models/         Domain models (Product)
Program.cs      App startup and dependency injection wiring
```

## Getting Started

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)

### Run

```bash
dotnet run
```

By default the app listens on:

- HTTP:  `http://localhost:5179`
- HTTPS: `https://localhost:7151`

The in-memory database is created and seeded with three sample products on startup.
Data is not persisted between runs.

## API Endpoints

Base route: `/api/products`

| Method | Route                | Description             |
|--------|----------------------|-------------------------|
| GET    | `/api/products`      | Get all products        |
| GET    | `/api/products/{id}` | Get a single product    |
| POST   | `/api/products`      | Create a new product    |
| PUT    | `/api/products/{id}` | Update an existing product |
| DELETE | `/api/products/{id}` | Delete a product        |

### Product model

```json
{
  "id": 1,
  "name": "Keyboard",
  "description": "Mechanical keyboard",
  "price": 79.99
}
```

### Example

```bash
curl http://localhost:5179/api/products
```

## OpenAPI

In the Development environment, the OpenAPI document is available at:

```
/openapi/v1.json
```

## Observability (OpenTelemetry + Docker Compose)

The app is instrumented with OpenTelemetry and emits **traces, metrics, and
logs** over OTLP. A Docker Compose stack runs the app alongside an OTLP
inspection proxy and Grafana's OpenTelemetry Collector (Alloy), plus Prometheus
and Grafana for dashboards.

### Telemetry flow

```
                                              --remote_write--> prometheus (metrics)
                                             /
app --OTLP--> otlp-proxy --OTLP--> alloy ----+---- OTLP -------> tempo (traces)      <--query-- grafana
                (prints raw                   \
                 OTLP payloads)                --- push -------> loki (logs)
```

- **app** — the instrumented API; exports OTLP to the proxy via
  `OTEL_EXPORTER_OTLP_ENDPOINT`.
- **otlp-proxy** — an OpenTelemetry Collector placed between the app and Alloy.
  It prints every span, metric, and log record in full (via the `debug`
  exporter) so you can see exactly what the OTLP messages look like, then
  forwards them on to Alloy.
- **alloy** — Grafana Alloy (Grafana's OTel Collector distribution). Fans each
  signal out to its backend: metrics are remote-written to Prometheus, traces
  are exported over OTLP to Tempo, and logs are pushed to Loki. Traces and logs
  are *also* sent to Alloy's debug output so you can still watch them live.
- **prometheus** — stores metrics for querying.
- **tempo** — stores traces for querying.
- **loki** — stores logs for querying.
- **grafana** — build dashboards on top of the Prometheus, Tempo, and Loki
  datasources (all auto-provisioned).
- **pyroscope** — continuous software profiling and resource usage tracking.  

### Run the stack

```bash
docker compose up --build
```

Generate some traffic:

```bash
curl http://localhost:8080/api/products
```

### Inspect the raw OTLP messages

The whole point of the proxy — watch the telemetry the app emits in real time:

```bash
docker compose logs -f otlp-proxy
```

### UIs

| Service    | URL                                   | Notes                     |
|------------|---------------------------------------|---------------------------|
| App API    | http://localhost:8080/api/products    | HTTP inside the container |
| Alloy UI   | http://localhost:12345                | Live pipeline graph       |
| Prometheus | http://localhost:9090                 | Query metrics             |
| Tempo      | http://localhost:3200                 | Traces (query via Grafana)|
| Loki       | http://localhost:3100                 | Logs (query via Grafana)  |
| Grafana    | http://localhost:3000                 | `admin` / `admin`         |
| Pyroscope  | http://localhost:4040                 | Live app performance      |

### Configuration

- Collector/observability configs live under [`otel/`](otel/).
- The exporter target is set with the standard `OTEL_EXPORTER_OTLP_ENDPOINT`
  environment variable (see `docker-compose.yml`). When running the app locally
  with `dotnet run`, it defaults to `http://localhost:4317`, so starting just
  the proxy (`docker compose up otlp-proxy`) is enough to inspect messages.

### Tear down

```bash
docker compose down          # stop containers
docker compose down -v       # also remove stored metrics/dashboards
```
