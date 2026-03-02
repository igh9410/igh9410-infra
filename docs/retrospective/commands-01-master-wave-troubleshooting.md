# Commands Log 01: Master Wave Troubleshooting and Completion

Date: 2026-03-02  
Namespace: `system-upgrade`

This file lists commands executed while diagnosing and confirming the control-plane upgrade.

## Initial state inspection (after master label trigger)

```bash
kubectl -n system-upgrade get pods -o wide
kubectl -n system-upgrade get jobs -o wide
kubectl -n system-upgrade get plans -o wide
kubectl get node controlplane -o wide
```

## Pending `apply-server-plan` pod diagnosis

```bash
kubectl -n system-upgrade describe pod apply-server-plan-on-controlplane-with-c9324b2b5bc5b17049-42vb8
kubectl -n system-upgrade get pod apply-server-plan-on-controlplane-with-c9324b2b5bc5b17049-42vb8 -o jsonpath='{.metadata.ownerReferences[*].kind}{"/"}{.metadata.ownerReferences[*].name}{"\n"}{.spec.nodeName}{"\n"}{.status.phase}{"\n"}'
kubectl get node controlplane -o jsonpath='{.metadata.name}{" unsched="}{.spec.unschedulable}{" taints="}{.spec.taints}{"\n"}'
kubectl get node controlplane --show-labels | sed -n '1,2p'
```

## Progress monitoring after plan fix/sync

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs -o wide
kubectl -n system-upgrade get pods -o wide
kubectl get node controlplane -o wide
sleep 8; kubectl -n system-upgrade get jobs,pods -o wide
kubectl get node controlplane -o jsonpath='{.metadata.name}{" ready="}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{" version="}{.status.nodeInfo.kubeletVersion}{"\n"}'
kubectl -n system-upgrade get plans -o wide
```

## Post-master workload checks

```bash
kubectl -n dev get deploy --no-headers
kubectl -n prod get deploy --no-headers
kubectl get clusters.postgresql.cnpg.io -A -o wide
```

