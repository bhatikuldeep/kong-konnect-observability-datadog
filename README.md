# Kong Konnect Observability with Datadog

Wires Kong Gateway (Kong Operator + Konnect) up to Datadog, with dashboards
filtered by `env`/`team`/`region`. Ships as a 3-Control-Plane example — fork
it and edit to match your own environment (see
[Adapting this](#adapting-this-to-your-environment)).

## Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Two telemetry configs](#two-telemetry-configs)
- [Tagging: env / team / region](#tagging-env--team--region)
- [Adapting this to your environment](#adapting-this-to-your-environment)
- [Tearing down](#tearing-down)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

## Architecture

```
terraform/  → 3 Konnect Control Planes (edit the map in variables.tf)
k8s/        → kind cluster + MetalLB + Kong Operator + Konnect CRDs,
              one namespace per CP
deck/       → sample Services/Routes + the OTel config per CP
datadog/    → Datadog Agent Helm values + one dashboard per telemetry path
```

Each CP has its own namespace and DataPlane. Kong Operator handles CP-DP
mTLS automatically. DataPlane image must be Kong Gateway **Enterprise**,
not OSS.

**Telemetry flow (OTel-only config, default):**

```
  Kong DataPlane            Datadog Agent             Datadog
  (opentelemetry    push   (OTLP receiver,    push   (Metrics,
    plugin)        ─────▶     :4318)         ─────▶  Traces, Logs)

  × one per CP              one shared Agent
```

Metrics, traces, and access logs all travel this same one-plugin,
one-endpoint path (`:4318`), on a `push_interval` — no scrape, no
Kubernetes Autodiscovery involved.

## Prerequisites

**Tools:**
- `terraform` >= 1.5, `kind`, `kubectl`, `helm`, `deck`
- [Task](https://taskfile.dev) (`brew install go-task`)
- A working Docker runtime

Run `task preflight` to check these are installed.

**Credentials:**
- A Konnect Personal Access Token (`kpat_...`)
- A Datadog **API key** (Organization Settings → API Keys)
- A Datadog **Application key** (Organization Settings → Application Keys)
  — required only for dashboard import (`task datadog:dashboard:otel`), a
  different credential type from the API key above

**Datadog custom tags — already configured, verify if merging into an
existing Agent:** this repo's `datadog/datadog-values.yaml` sets two things
this whole setup depends on:
1. `otlp_config.metrics.resource_attributes_as_tags: true` (via
   `agents.customAgentConfig` + `agents.useConfigMap: true`) — without
   this, custom tags like `env`/`team`/`region` are silently dropped by
   Datadog, since they aren't OTel semantic-convention names.
2. `tags: []` — no Agent-global tags, so a per-CP `env` never collides
   with an org-wide one.

If you're deploying the Datadog Agent fresh (via `task up` /
`task datadog:up`), both are already handled — nothing to do. If you're
pointing this at an **existing** shared Agent instead, add both settings
to that Agent's config, or your `env`/`team`/`region` tags won't appear.

## Quickstart

```bash
cp .env.example .env
# edit .env: KONNECT_PAT, KONNECT_SERVER_URL, DD_API_KEY, DD_APP_KEY, DD_SITE

task up                      # Terraform → kind → MetalLB → Kong Operator →
                              # 3 DataPlanes → decK sync → Datadog Agent
task datadog:dashboard:otel  # import the dashboard
task demo:test:all           # send test traffic through all 3 CPs
task status                  # CRD/pod/proxy-IP status for all 3 CPs
```

Safe to re-run `task up` if it fails partway. Give the dashboard a minute
after traffic before expecting graphs to fill in (Kong pushes metrics every
10s).

**Seeing the data:** APM/Logs → filter `service:<control-plane-name>`.
Metrics Explorer → search `kong.*` / `http.server.*`. Dashboard's template
variables filter by env/team/region.

## Two telemetry configs

| Config | Path | Metrics via |
|---|---|---|
| OTel-only (default, `task up`) | `deck/kong-otel-cp1/2/3.yaml` | OpenTelemetry plugin push |
| OTel + Prometheus (comparison example) | `deck/kong.yaml` | Prometheus plugin, Agent scrape |

Each has its own dashboard:
[`datadog/dashboard-otel.json`](datadog/dashboard-otel.json),
[`datadog/dashboard-prometheus.json`](datadog/dashboard-prometheus.json).
Both import via `task datadog:dashboard:otel` / `task datadog:dashboard`,
or can be pasted directly into Datadog's UI (Dashboards → New Dashboard →
Import dashboard JSON) if you just want the dashboard against your own
existing Kong + Datadog setup, without running any of this repo's
infrastructure.

The Prometheus example needs its own standalone Control Plane:
`SINGLE_CP_NAME=<name> task deck:sync:single-cp-example`.

## Tagging: env / team / region

Every dashboard panel filters by `env`/`team`/`region`. These come only
from each CP's own decK config (`resource_attributes` on the
`opentelemetry` plugin) — never from Kubernetes or Datadog Agent-global
tags (the Agent's own tags are intentionally empty). See the comments in
`datadog/datadog-values.yaml` and `terraform/variables.tf` for why.

Changing a CP's env/team/region is a two-file edit: `terraform/variables.tf`
+ that CP's `deck/kong-otel-cpN.yaml`. Nothing else needs to change.

## Adapting this to your environment

| To change... | Edit... |
|---|---|
| Number of Control Planes | `terraform/variables.tf`'s `control_planes` map, a matching `deck/kong-otel-cpN.yaml`, `Taskfile.yaml`'s `CPS` var, and `k8s/manifests/shared/01-konnect-auth.yaml` |
| env / team / region values | That CP's `control_planes` entry + its `deck/kong-otel-cpN.yaml` `resource_attributes` |
| Your own Services/Routes | Replace `services:`/`routes:`/`upstreams:` in each `deck/kong-otel-cpN.yaml` |
| Datadog site / Konnect region | `DD_SITE` / `KONNECT_SERVER_URL` in `.env` |
| Dashboard panels | Edit `datadog/dashboard-otel.json`, re-run `task datadog:dashboard:otel` (updates in place) |

## Tearing down

```bash
task down   # deletes the kind cluster AND destroys all 3 Konnect Control Planes
```

`task datadog:down` alone only removes the Datadog Agent.

## Troubleshooting

- **Proxy IP unreachable** — only routable to the host on OrbStack; use
  `kubectl port-forward` on Docker Desktop/Colima.
- **Dashboard shows "No Data"** — run `task demo:test:all`, wait ~30-60s.
- **`KongReferenceGrant` rejects an empty `group`** — use the literal
  string `group: core`, not `""`.
- **decK sync fails with an auth error** — confirm
  `kubectl -n kong get secret konnect-api-auth-secret` exists (created by
  `task cluster:up`) and matches `.env`'s `KONNECT_PAT`.

## Reference

- [Kong Operator + Konnect CRDs](https://developer.konghq.com/operator/get-started/konnect-crds/)
- [OpenTelemetry plugin reference](https://developer.konghq.com/plugins/opentelemetry/reference)
- [Kong Gateway OpenTelemetry metrics reference](https://developer.konghq.com/gateway/otel-metrics)
- [Datadog Unified Service Tagging](https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/)
- [Datadog OTLP metric types](https://docs.datadoghq.com/metrics/open_telemetry/otlp_metric_types/)
