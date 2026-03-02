# Commands Log 10: Prod Gramnuri Planned Switchover to `node04`

Date: 2026-03-02  
Cluster: `prod-cnpg-database/prod-gramnuri-db-cluster`  
Target primary: `prod-gramnuri-db-cluster-4` (`node04`)

## Pre-check

```bash
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o wide
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.currentPrimary}{"\n"}{.status.currentPrimaryTimestamp}{"\n"}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}'
```

Observed before switchover:
- Status: `Cluster in healthy state`
- Current primary: `prod-gramnuri-db-cluster-1` (`node01`)
- Ready: `3/3`
- `currentPrimaryTimestamp`: `2026-03-02T10:28:45.246038Z`

## Planned switchover command

Start time (`UTC`): `2026-03-02T12:13:45Z`

```bash
kubectl cnpg promote prod-gramnuri-db-cluster prod-gramnuri-db-cluster-4 -n prod-cnpg-database
```

Command response:
- `Node prod-gramnuri-db-cluster-4 in cluster prod-gramnuri-db-cluster will be promoted`

## Monitoring output (key points)

- `2026-03-02T12:13:45Z`: `Switchover in progress`, primary=`prod-gramnuri-db-cluster-1`, ready=`3/3`
- `2026-03-02T12:13:49Z`: `Switchover in progress`, primary=`prod-gramnuri-db-cluster-4`, ready=`2/3`
- `2026-03-02T12:14:14Z`: `Cluster in healthy state`, primary=`prod-gramnuri-db-cluster-4`, ready=`3/3`

Also observed from cluster status during switchover:
- New `currentPrimaryTimestamp`: `2026-03-02T12:13:48.766470Z`

Operator log confirmation (`cnpg-system/cloudnative-pg-operator`):
- `2026-03-02T12:13:45.402301171Z`: switchover in progress (`targetPrimary=prod-gramnuri-db-cluster-4`)
- `2026-03-02T12:13:52.589343564Z`: `Setting primary label` on `prod-gramnuri-db-cluster-4`
- `2026-03-02T12:14:12.512065407Z`: `Cluster has become healthy`

## Measured duration

- Primary change latency (`start` -> `currentPrimaryTimestamp`): about `3.8s`
- Full switchover to healthy (`start` -> healthy in monitor loop): `29s`

## Post-check

```bash
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o wide
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
```

Observed after switchover:
- Status: `Cluster in healthy state`
- Current primary: `prod-gramnuri-db-cluster-4` (`node04`)
- Ready: `3/3`
- Old primary `prod-gramnuri-db-cluster-1` restarted once during recovery and returned `Running`.

## App log check: `prod/gramnuri-api` during switchover window

Checked window:
- Core switchover window: `2026-03-02T12:13:45Z` to `2026-03-02T12:14:14Z` (`UTC`)
- Query buffer used for inspection: `2026-03-02T12:12:45Z` to `2026-03-02T12:15:14Z` (`UTC`)

Commands used:

```bash
kubectl -n prod get pods -l app=gramnuri-api -o wide
for p in $(kubectl -n prod get pods -l app=gramnuri-api -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  kubectl -n prod logs "$p" --since-time="2026-03-02T12:12:45Z" --timestamps > "/tmp/${p}.log"
  awk -v s="2026-03-02T12:12:45Z" -v e="2026-03-02T12:15:14Z" '$1 >= s && $1 <= e' "/tmp/${p}.log" > "/tmp/${p}.window.log"
  rg -i -n 'postgres|sqlstate|database system is starting up|database connection|db connection|connection refused|econn|etimedout|timeout|too many connections|could not connect|pool|sequelize|prisma|typeorm|pgerror|error' "/tmp/${p}.window.log" || true
done
```

Observed:
- Pod `gramnuri-api-d7c845648-fpf6m`: no DB-related error matches in window.
- Pod `gramnuri-api-d7c845648-llzjk`: no DB-related error matches in window.
- No `5xx` or `error/warn` log matches found in this window.
