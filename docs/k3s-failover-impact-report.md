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
| `gramnuri-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-web` | `prod` | `0` | No `status:500` log lines in window |

### POST Traffic Presence During Failover
- POST requests were observed during failover window (`10:25:44Z` to `10:28:57Z`):
  - `gramnuri-api`: `7` POST requests with `200`
  - `gramnuri-api`: `1` POST request with `429` (rate limit), not DB error
- Exact primary promotion sub-window (`10:28:41.640Z` to `10:28:45.246Z`):
  - No POST requests were observed in API logs.

## Case D: `node03` Worker Upgrade Phase (`prod-gramnuri` focus)

### Timeline (UTC)
- `2026-03-02T10:37:25Z`  
  SUC job start: `apply-agent-plan-on-node03-with-c9324b2b5bc5b170499aebf75-7e4b9`
- `2026-03-02T10:38:29Z`  
  SUC job completion (`Duration: 64s`)

### Observed Durations
- Worker upgrade execution (`node03`): about `64s`

### Per-App Impact (Observed in Logs)
Collection window: `--since-time=2026-03-02T10:37:00Z`

| App | Namespace | Observed 500 count | Notes |
| --- | --- | --- | --- |
| `gramnuri-api` | `prod` | `0` | Status histogram observed only `200` responses in this window |
| `gramnuri-web` | `prod` | `0` detected | No `500`/DB-related error lines observed |

### DB Impact (Observed)
- `prod-gramnuri-db-cluster` primary remained `prod-gramnuri-db-cluster-1` on `node01` during and after worker upgrade.
- No CNPG failover/recovery events for `prod-gramnuri` were observed at or after `2026-03-02T10:37:00Z`.
- DB pod restart counters remained `0` in post-upgrade checks (`prod-gramnuri-db-cluster-{1,2,4}`).

## Interpretation
- There was a brief write-path disruption visible in `dev/gramnuri-api` during primary promotion.
- `prod-artskorner` failover completed significantly faster than the dev case and no app `500` logs were observed.
- `prod-gramnuri` promotion itself was fast, but total failover time was longer due to the old primary termination/stuck phase before final promotion.
- For `prod-gramnuri`, API POST traffic existed during failover and returned `200/429` only; there were no observed `500` responses.
- During `node03` upgrade, no `prod-gramnuri` app or DB downtime signal was detected from logs/events/pod restarts.
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
for d in gramnuri-api gramnuri-web; do echo "=== prod/$d ==="; kubectl -n prod logs deploy/$d --since-time=2026-03-02T10:25:00Z 2>/dev/null | rg '"status":500' || true; done
START=2026-03-02T10:25:44Z; END=2026-03-02T10:28:57Z; for p in $(kubectl -n prod get pods -o name | rg 'gramnuri-api'); do kubectl -n prod logs "$p" --since-time=2026-03-02T10:25:00Z --timestamps 2>/dev/null | awk -v s="$START" -v e="$END" '$1>=s && $1<=e' | rg '"method":"POST"' | rg -o '"status":[0-9]+' | sed 's/"status"://' ; done | sort | uniq -c
START=2026-03-02T10:28:41.640Z; END=2026-03-02T10:28:45.246Z; for p in $(kubectl -n prod get pods -o name | rg 'gramnuri-api'); do kubectl -n prod logs "$p" --since-time=2026-03-02T10:28:30Z --timestamps 2>/dev/null | awk -v s="$START" -v e="$END" '$1>=s && $1<=e' | rg '"method":"POST"' ; done
kubectl -n system-upgrade get jobs -o jsonpath='{range .items[?(@.metadata.name=="apply-agent-plan-on-node03-with-c9324b2b5bc5b170499aebf75-7e4b9")]}{.metadata.name}{"\tstart="}{.status.startTime}{"\tcompletion="}{.status.completionTime}{"\n"}{end}'
kubectl -n prod-cnpg-database get events -o json | jq -r '.items[] | select(.lastTimestamp >= "2026-03-02T10:37:00Z") | [.lastTimestamp,.type,.reason,.involvedObject.kind,.involvedObject.name,.message] | @tsv'
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since-time=2026-03-02T10:37:00Z 2>/dev/null | rg 'prod-gramnuri-db-cluster|Failing over|initiating a failover|Cluster has become healthy|Cannot extract Pod status|ERROR|WARN' -i || true
for p in $(kubectl -n prod get pods -o name | rg 'gramnuri-api|gramnuri-web'); do echo "=== $p ==="; kubectl -n prod logs "$p" --since-time=2026-03-02T10:37:00Z 2>/dev/null | rg '"status":500|ECONN|connection refused|database system is starting up|timeout|postgres|sqlstate|internal server error|error' -i || true; done
```

## Final Downtime Summary (Per App and DB)

### Apps (Observed From Logs)

| App | Namespace | Downtime Detected? | Evidence |
| --- | --- | --- | --- |
| `gramnuri-api` | `dev` | Yes (brief) | `2`x HTTP `500` during dev DB failover; observed burst about `1.4s` |
| `gramnuri-web` | `dev` | No | No `500` log lines in measured windows |
| `artskorner-api` | `prod` | No | No `500` log lines in measured windows |
| `gramnuri-api` | `prod` | No | No `500`; during prod-gramnuri failover, observed POST traffic returned `200/429` |
| `gramnuri-web` | `prod` | No | No `500`/DB-related error lines in measured windows |

### Databases (Observed + Inferred)

| DB Cluster | Downtime Detected? | Evidence |
| --- | --- | --- |
| `dev-gramnuri-db-cluster` | Yes (write-path disruption inferred) | CNPG failover occurred; app observed brief `500` burst during promotion |
| `prod-artskorner-db-cluster` | No app-visible downtime observed | CNPG failover completed (~`16.2s` full / `3.7s` promotion); no app `500` observed |
| `prod-gramnuri-db-cluster` | No app-visible downtime observed; brief primary disruption on DB side | CNPG `FailingOver` + old primary readiness probe `500`; API POSTs in failover window returned `200/429`, no `500` |
| `prod-gramnuri-db-cluster` during `node03` upgrade | No | Primary unchanged, no CNPG failover events, no DB pod restarts |

### Bottom Line
- Confirmed app-visible interruption: `dev/gramnuri-api` only.
- For production (`gramnuri`), no app-visible downtime was detected in measured failover/upgrade windows.
- DB primary failover events still indicate a short internal transition window; if no writes hit that exact instant, user-facing errors may not occur.
