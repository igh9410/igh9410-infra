# Commands Log 06: Dev Primary Handover Before `node03` Upgrade

Date: 2026-03-02  
Cluster: `cnpg-database/dev-gramnuri-db-cluster`

## Baseline checks

```bash
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o wide
kubectl -n cnpg-database get pods -l cnpg.io/cluster=dev-gramnuri-db-cluster -o wide
```

## Trigger failover by deleting current primary

```bash
PRIMARY=$(kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o jsonpath='{.status.currentPrimary}'); echo "Deleting primary: $PRIMARY"; kubectl -n cnpg-database delete pod "$PRIMARY"
```

## Continuous monitoring during failover

```bash
for i in {1..24}; do echo "--- $(date -Iseconds)"; kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o wide; kubectl -n cnpg-database get pods -l cnpg.io/cluster=dev-gramnuri-db-cluster -o wide; echo; sleep 5; done
for i in {1..24}; do echo "--- $(date -Iseconds)"; kubectl -n dev get deploy gramnuri-api gramnuri-web --no-headers; sleep 5; done
```

## Delay investigation (long `Terminating` / slow promotion)

```bash
kubectl -n cnpg-database describe pod dev-gramnuri-db-cluster-1
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o yaml | sed -n '1,260p'
kubectl -n cnpg-database get pod dev-gramnuri-db-cluster-1 -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.metadata.finalizers}{"\n"}{.status.phase}{"\n"}'
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o jsonpath='{.status.phase}{"\n"}{.status.phaseReason}{"\n"}{.status.currentPrimary}{"\n"}{.status.targetPrimary}{"\n"}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}'
kubectl -n cnpg-database get events --sort-by=.lastTimestamp | tail -n 30
kubectl get pods -A | rg -i 'cloudnative-pg|cnpg.*operator|postgresql-operator'
```

## Acceleration step used

```bash
kubectl -n cnpg-database delete pod dev-gramnuri-db-cluster-1 --grace-period=0 --force
```

## Operator and cluster confirmation

```bash
kubectl -n cnpg-system logs deploy/cloudnative-pg-operator --since=5m | tail -n 120
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o wide
kubectl -n cnpg-database get pods -l cnpg.io/cluster=dev-gramnuri-db-cluster -o wide
PRIMARY=$(kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o jsonpath='{.status.currentPrimary}'); echo "primary=$PRIMARY"; kubectl -n cnpg-database get pod "$PRIMARY" -o wide
kubectl -n cnpg-database get cluster dev-gramnuri-db-cluster -o wide && kubectl -n dev get deploy gramnuri-api gramnuri-web --no-headers
```

## Measured impact
- Separate impact/timeline report:
  - `docs/k3s-failover-impact-report.md`
