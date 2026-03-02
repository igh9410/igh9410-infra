# K3s/CNPG Failover Impact Report

Date: 2026-03-02  
Cluster context: `default`

## Scope
- Scenario: controlled primary handover for `cnpg-database/dev-gramnuri-db-cluster`
- Goal: measure observed interruption and application impact before `node03` upgrade wave

## Timeline (UTC)
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

## Observed Durations
- Full CNPG failover phase (event start to healthy): about `3m27s`
- Primary promotion window (new primary election to current primary timestamp): about `11.4s`
- Observed dev API error burst: about `1.4s`

## Per-App Impact (Observed in Logs)
Collection window: `--since-time=2026-03-02T10:07:00Z`

| App | Namespace | Observed 500 count | Notes |
| --- | --- | --- | --- |
| `gramnuri-api` | `dev` | `2` | `POST /api/v1/generations/landscape` at `10:10:36Z`, `10:10:37Z` |
| `gramnuri-web` | `dev` | `0` | No `status:500` log lines in window |
| `artskorner-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-api` | `prod` | `0` | No `status:500` log lines in window |
| `gramnuri-web` | `prod` | `0` | No `status:500` log lines in window |

## Interpretation
- There was a brief write-path disruption visible in `dev/gramnuri-api` during primary promotion.
- Observed interruption matched a short failover window (`~10–12s` class), with only a subset of requests failing.
- Application log observation is traffic-dependent; zero log errors is not a hard guarantee of zero user impact.

## Commands Used for Measurement
```bash
kubectl -n cnpg-database get events --field-selector involvedObject.kind=Cluster,involvedObject.name=dev-gramnuri-db-cluster -o jsonpath='{range .items[*]}{.lastTimestamp}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}' | sort
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since=50m | rg 'dev-gramnuri-db-cluster|Cluster has become healthy|Failing over|initiating a failover|Setting primary label'
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.currentPrimary}{"\n"}{.status.currentPrimaryTimestamp}{"\n"}{.status.targetPrimary}{"\n"}{.status.targetPrimaryTimestamp}{"\n"}'
for ns in dev prod; do for d in $(kubectl -n $ns get deploy -o jsonpath='{.items[*].metadata.name}'); do echo "=== $ns/$d ==="; kubectl -n $ns logs deploy/$d --since-time=2026-03-02T10:07:00Z 2>/dev/null | rg '"status":500' || true; done; done
```

