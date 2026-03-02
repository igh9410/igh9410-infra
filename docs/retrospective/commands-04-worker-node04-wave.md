# Commands Log 04: Worker Wave (`node04`)

Date: 2026-03-02  
Plan: `agent-plan` (pinned `v1.34.4+k3s1`)

## Pre-trigger checks

```bash
kubectl get node node04 -o wide
kubectl -n system-upgrade get plans -o wide
kubectl get node node04 --show-labels | sed -n '1,2p'
```

## Trigger wave

```bash
kubectl label node node04 upgrade-wave=active --overwrite
```

## Live monitoring

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs,pods -o wide
kubectl get node node04 -o wide
sleep 20; kubectl -n system-upgrade get jobs,pods -o wide
sleep 20; kubectl get node node04 -o wide
sleep 20; kubectl -n system-upgrade get plans -o wide
sleep 15; kubectl -n system-upgrade get jobs -o wide
sleep 15; kubectl -n system-upgrade get plans -o wide
sleep 15; kubectl get node node04 -o jsonpath='{.metadata.name}{" unsched="}{.spec.unschedulable}{" ready="}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{" version="}{.status.nodeInfo.kubeletVersion}{"\n"}'
```

## Post-completion cleanup and validation

```bash
kubectl label node node04 upgrade-wave-
kubectl -n dev get deploy --no-headers && kubectl -n prod get deploy --no-headers
kubectl get clusters.postgresql.cnpg.io -A -o wide && kubectl -n prod-cnpg-database get pods -o wide && kubectl -n cnpg-database get pods -o wide
kubectl get nodes -o wide
```

