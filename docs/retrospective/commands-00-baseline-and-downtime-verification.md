# Commands Log 00: Baseline and Downtime Verification

Date: 2026-03-02  
Context: `kubectl` context `default`

This file lists the baseline and verification commands executed before and during upgrade preparation.

## Cluster and workload baseline

```bash
kubectl get nodes -o wide
kubectl -n dev get deploy,pods,pdb
kubectl -n prod get deploy,pods,pdb
kubectl get clusters.postgresql.cnpg.io -A -o wide
kubectl -n prod-cnpg-database get pods -o wide
kubectl -n cnpg-database get pods -o wide
```

## Production replication checks (CNPG/Postgres)

```bash
kubectl -n prod-cnpg-database exec -i prod-gramnuri-db-cluster-2 -- psql -U postgres -d postgres -Atc "show synchronous_standby_names; select application_name||':'||sync_state from pg_stat_replication order by application_name;"
kubectl -n prod-cnpg-database exec -i prod-artskorner-db-cluster-1 -- psql -U postgres -d postgres -Atc "show synchronous_standby_names; select application_name||':'||sync_state from pg_stat_replication order by application_name;"
```

## Node labels and SUC resources

```bash
kubectl get nodes --show-labels | rg 'upgrade-server|upgrade-wave|^NAME|controlplane|node0[1-4]'
kubectl -n system-upgrade get deploy,pods,plans,jobs
```

## Service and ingress discovery for probe design

```bash
kubectl -n dev get svc
kubectl -n prod get svc
kubectl get ingress -A
kubectl -n prod-cnpg-database get svc
kubectl -n cnpg-database get svc
```

## One-shot in-cluster HTTP response validation

```bash
kubectl -n dev run curlcheck-dev --image=curlimages/curl:8.12.1 --restart=Never --rm -i --command -- sh -c 'for u in http://gramnuri-api.dev.svc.cluster.local http://gramnuri-web.dev.svc.cluster.local; do c=$(curl -sS -o /dev/null -w "%{http_code}" "$u" || echo 000); echo "$u $c"; done'
kubectl -n prod run curlcheck-prod --image=curlimages/curl:8.12.1 --restart=Never --rm -i --command -- sh -c 'for u in http://gramnuri-api.prod.svc.cluster.local http://gramnuri-web.prod.svc.cluster.local http://artskorner-api.prod.svc.cluster.local; do c=$(curl -sS -o /dev/null -w "%{http_code}" "$u" || echo 000); echo "$u $c"; done'
```

