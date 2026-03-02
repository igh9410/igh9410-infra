# K3s/CNPG Failover Impact Report

Date: 2026-03-02  
Cluster context: `default`

## Scope
- Scenarios:
  - controlled primary handover for `cnpg-database/dev-gramnuri-db-cluster`
  - controlled primary handover for `prod-cnpg-database/prod-artskorner-db-cluster`
  - controlled primary handover for `prod-cnpg-database/prod-gramnuri-db-cluster`
- Goal: measure observed interruption and application impact before `node03` upgrade wave

## Case A: `dev-gramnuri-db-cluster`

### Timeline (UTC)
- `2026-03-02T10:07:37Z`  
  CNPG cluster event: `FailingOver` (`dev-gramnuri-db-cluster`)
- `2026-03-02T10:10:13.952Z`  
  CNPG operator: `Current primary isn't healthy, initiating a failover`
- `2026-03-02T10:10:31.255Z`  
  CNPG operator: `Failing over`, `newPrimary=dev-gramnuri-db-cluster-2`
- `2026-03-02T10:10:42.681Z`  
  Cluster status: `currentPrimaryTimestamp`
- `2026-03-02T10:11:04.055Z`  
  CNPG operator: `Cluster has become healthy`

### Observed Durations
- Full CNPG failover phase (event start to healthy): about `3m27s`
- Primary promotion window (new primary election to current primary timestamp): about `11.4s`
- Observed dev API error burst: about `1.4s`

### Per-App Impact (Observed in Logs)
Collection window: `--since-time=2026-03-02T10:07:00Z`

| App | Namespace | Observed 500 count | Notes |
| --- | --- | --- | --- |
| `gramnuri-api` | `dev` | `2` | `POST /api/v1/generations/landscape` at `10:10:36Z`, `10:10:37Z` |
| `gramnuri-web` | `dev` | `0` | No `status:500` log lines in window |
| `artskorner-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-web` | `prod` | `0` | No `status:500` log lines in window |

## Case B: `prod-artskorner-db-cluster`

### Timeline (UTC)
- `2026-03-02T10:19:36Z`  
  CNPG cluster events: `FailingOver`, `FailoverTarget`
- `2026-03-02T10:19:36.669Z`  
  CNPG operator: `Current primary isn't healthy, initiating a failover`
- `2026-03-02T10:19:36.691Z`  
  CNPG operator: `Failing over`, `newPrimary=prod-artskorner-db-cluster-2`
- `2026-03-02T10:19:40.383Z`  
  Cluster status: `currentPrimaryTimestamp`
- `2026-03-02T10:19:52.239Z`  
  CNPG operator: `Cluster has become healthy`

### Observed Durations
- Full CNPG failover phase (event start to healthy): about `16.2s`
- Primary promotion window (new primary election to current primary timestamp): about `3.7s`
- Observed prod API error burst: `0` entries observed in app logs for this window

### Per-App Impact (Observed in Logs)
Collection window: `--since-time=2026-03-02T10:18:30Z`

| App | Namespace | Observed 500 count | Notes |
| --- | --- | --- | --- |
| `artskorner-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-web` | `prod` | `0` | No `status:500` log lines in window |

## Case C: `prod-gramnuri-db-cluster`

### Timeline (UTC)
- `2026-03-02T10:25:44Z`  
  CNPG cluster event: `FailingOver` from `prod-gramnuri-db-cluster-2`
- `2026-03-02T10:28:41.616Z`  
  CNPG operator: `Current primary isn't healthy, initiating a failover`
- `2026-03-02T10:28:41.630Z`  
  CNPG operator: `Failing over`, `newPrimary=prod-gramnuri-db-cluster-1`
- `2026-03-02T10:28:45.246Z`  
  Cluster status: `currentPrimaryTimestamp`
- `2026-03-02T10:28:57.398Z`  
  CNPG operator: `Cluster has become healthy`

### Observed Durations
- Full CNPG failover phase (event start to healthy): about `3m13s`
- Primary promotion window (new primary election to current primary timestamp): about `3.6s`
- Observed prod API error burst: `0` entries observed in app logs for this window

### Per-App Impact (Observed in Logs)
Collection window: `--since-time=2026-03-02T10:25:00Z`

| App | Namespace | Observed 500 count | Notes |
| --- | --- | --- | --- |
| `artskorner-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-web` | `prod` | `0` | No `status:500` log lines in window |

## Interpretation
- There was a brief write-path disruption visible in `dev/gramnuri-api` during primary promotion.
- `prod-artskorner` failover completed significantly faster than the dev case and no app `500` logs were observed.
- `prod-gramnuri` promotion itself was fast, but total failover time was longer due to the old primary termination/stuck phase before final promotion.
- Application log observation is traffic-dependent; zero log errors is not a hard guarantee of zero user impact.

## Commands Used for Measurement
```bash
kubectl -n cnpg-database get events --field-selector involvedObject.kind=Cluster,involvedObject.name=dev-gramnuri-db-cluster -o jsonpath='{range .items[*]}{.lastTimestamp}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}' | sort
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since=50m | rg 'dev-gramnuri-db-cluster|Cluster has become healthy|Failing over|initiating a failover|Setting primary label'
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.currentPrimary}{"\n"}{.status.currentPrimaryTimestamp}{"\n"}{.status.targetPrimary}{"\n"}{.status.targetPrimaryTimestamp}{"\n"}'
for ns in dev prod; do for d in $(kubectl -n $ns get deploy -o jsonpath='{.items[*].metadata.name}'); do echo "=== $ns/$d ==="; kubectl -n $ns logs deploy/$d --since-time=2026-03-02T10:07:00Z 2>/dev/null | rg '"status":500' || true; done; done
kubectl -n prod-cnpg-database get events --field-selector involvedObject.kind=Cluster,involvedObject.name=prod-artskorner-db-cluster -o jsonpath='{range .items[*]}{.lastTimestamp}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}' | sort
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since=30m | rg 'prod-artskorner-db-cluster|Cluster has become healthy|Failing over|initiating a failover|Setting primary label'
kubectl -n prod-cnpg-database get cluster prod-artskorner-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.currentPrimary}{"\n"}{.status.currentPrimaryTimestamp}{"\n"}{.status.targetPrimary}{"\n"}{.status.targetPrimaryTimestamp}{"\n"}'
for d in artskorner-api gramnuri-api gramnuri-web; do echo "=== prod/$d ==="; kubectl -n prod logs deploy/$d --since-time=2026-03-02T10:18:30Z 2>/dev/null | rg '"status":500' || true; done
kubectl -n prod-cnpg-database get events --field-selector involvedObject.kind=Cluster,involvedObject.name=prod-gramnuri-db-cluster -o jsonpath='{range .items[*]}{.lastTimestamp}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}' | sort
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since=60m | rg 'prod-gramnuri-db-cluster|Cluster has become healthy|Failing over|initiating a failover|Setting primary label'
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.currentPrimary}{"\n"}{.status.currentPrimaryTimestamp}{"\n"}{.status.targetPrimary}{"\n"}{.status.targetPrimaryTimestamp}{"\n"}'
for d in artskorner-api gramnuri-api gramnuri-web; do echo "=== prod/$d ==="; kubectl -n prod logs deploy/$d --since-time=2026-03-02T10:25:00Z 2>/dev/null | rg '"status":500' || true; done
```
