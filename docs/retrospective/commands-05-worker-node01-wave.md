# Commands Log 05: Worker Wave (`node01`)

Date: 2026-03-02  
Plan: `agent-plan` (pinned `v1.34.4+k3s1`)

## Pre-trigger checks

```bash
kubectl get node node01 -o wide
kubectl -n system-upgrade get plans -o wide
kubectl get node node01 --show-labels | sed -n '1,2p'
kubectl get pods -A -o wide --field-selector=status.phase=Running | rg '\snode01\s'
```

## Trigger wave

```bash
kubectl label node node01 upgrade-wave=active --overwrite
```

## Live monitoring

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs,pods -o wide
kubectl get node node01 -o wide
sleep 20; kubectl -n system-upgrade get jobs,pods -o wide
sleep 20; kubectl get node node01 -o wide
sleep 20; kubectl -n system-upgrade get plans -o wide
sleep 15; kubectl -n system-upgrade get jobs -o wide
sleep 15; kubectl -n system-upgrade get plans -o wide
sleep 15; kubectl get node node01 -o jsonpath='{.metadata.name}{" unsched="}{.spec.unschedulable}{" ready="}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{" version="}{.status.nodeInfo.kubeletVersion}{"\n"}'
```

## Post-completion cleanup and validation

```bash
kubectl label node node01 upgrade-wave-
kubectl -n system-upgrade get plans -o wide
kubectl get nodes -o wide
kubectl -n dev get deploy --no-headers && kubectl -n prod get deploy --no-headers && kubectl get clusters.postgresql.cnpg.io -A -o wide
kubectl -n prod-cnpg-database get pods -o wide && kubectl -n cnpg-database get pods -o wide
kubectl -n prod-cnpg-database exec -i $(kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='{.status.currentPrimary}') -- psql -U postgres -d postgres -Atc "show synchronous_standby_names; select application_name||':'||sync_state from pg_stat_replication order by application_name;"
kubectl -n prod-cnpg-database exec -i $(kubectl -n prod-cnpg-database get cluster prod-artskorner-db-cluster -o jsonpath='{.status.currentPrimary}') -- psql -U postgres -d postgres -Atc "show synchronous_standby_names; select application_name||':'||sync_state from pg_stat_replication order by application_name;"
```

