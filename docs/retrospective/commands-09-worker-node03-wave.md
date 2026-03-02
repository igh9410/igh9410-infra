# Commands Log 09: Worker Wave (`node03`)

Date: 2026-03-02  
Plan: `agent-plan` (pinned `v1.34.4+k3s1`)
Scope: `gramnuri` checks only (artskorner skipped by request)

## Pre-trigger checks

```bash
kubectl get node node03 --show-labels
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs,pods -o wide
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='phase={.status.phase}{" primary="}{.status.currentPrimary}{" currentPrimaryTs="}{.status.currentPrimaryTimestamp}{"\n"}'
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
kubectl -n prod get deploy gramnuri-api gramnuri-web --no-headers
```

## Trigger wave

```bash
kubectl uncordon node03
kubectl label node node03 upgrade-wave=active --overwrite
kubectl get node node03 --show-labels
```

## Live monitoring

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs,pods -o wide
kubectl get node node03 -o wide
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='phase={.status.phase}{" primary="}{.status.currentPrimary}{"\n"}'
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
kubectl -n prod get deploy gramnuri-api gramnuri-web --no-headers
for i in {1..12}; do echo "--- $(date -Iseconds)"; kubectl get node node03 -o jsonpath='node03 version={.status.nodeInfo.kubeletVersion} unschedulable={.spec.unschedulable} ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}'; kubectl -n system-upgrade get plans -o wide | rg '^agent-plan'; kubectl -n system-upgrade get jobs --no-headers | rg 'agent-plan-on-node03|apply-agent-plan'; kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='prod-gramnuri phase={.status.phase} primary={.status.currentPrimary}{"\n"}'; kubectl -n prod get deploy gramnuri-api gramnuri-web --no-headers | awk '{print $1" ready="$2" avail="$5}'; sleep 5; done
```

## Post-completion cleanup and validation

```bash
kubectl label node node03 upgrade-wave-
kubectl get node node03 -o wide --show-labels
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs --sort-by=.metadata.creationTimestamp | tail -n 5
kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='phase={.status.phase}{" primary="}{.status.currentPrimary}{"\n"}'
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
kubectl -n prod get deploy gramnuri-api gramnuri-web --no-headers
kubectl get nodes -o wide
```

