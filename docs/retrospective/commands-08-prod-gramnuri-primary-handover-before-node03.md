# Commands Log 08: Prod Gramnuri Primary Handover Before `node03` Upgrade

Date: 2026-03-02  
Cluster: `prod-cnpg-database/prod-gramnuri-db-cluster`

## Baseline checks

```bash
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o wide
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
kubectl -n prod get deploy gramnuri-api gramnuri-web --no-headers
```

## Trigger planned switchover to a replica

```bash
TARGET=prod-gramnuri-db-cluster-1; echo "Switchover target: $TARGET"; kubectl cnpg promote prod-gramnuri-db-cluster "$TARGET" -n prod-cnpg-database
```

## Continuous monitoring during switchover

```bash
for i in {1..40}; do echo "--- $(date -Iseconds)"; kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o wide; kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide; echo; sleep 4; done
for i in {1..40}; do echo "--- $(date -Iseconds)"; kubectl -n prod get deploy gramnuri-api gramnuri-web --no-headers; sleep 4; done
```

## Recovery actions when old primary remained stuck

```bash
kubectl -n prod-cnpg-database delete pod prod-gramnuri-db-cluster-2 --grace-period=0 --force
kubectl cordon node03
```

## Timeline and app impact measurements

```bash
kubectl -n prod-cnpg-database get events --field-selector involvedObject.kind=Cluster,involvedObject.name=prod-gramnuri-db-cluster -o jsonpath='{range .items[*]}{.lastTimestamp}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}' | sort
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since=60m | rg 'prod-gramnuri-db-cluster|Cluster has become healthy|Failing over|initiating a failover|Setting primary label'
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.currentPrimary}{"\n"}{.status.currentPrimaryTimestamp}{"\n"}{.status.targetPrimary}{"\n"}{.status.targetPrimaryTimestamp}{"\n"}'
for d in gramnuri-api gramnuri-web; do echo "=== prod/$d ==="; kubectl -n prod logs deploy/$d --since-time=2026-03-02T10:25:00Z 2>/dev/null | rg '"status":500' || true; done
```
