# System Upgrade Controller (GitOps)

This directory is managed by ArgoCD and contains:
- `crd.yaml`
- `system-upgrade-controller.yaml`
- `plans.yaml` (pinned k3s upgrade plans)

## Pinned target version
- `v1.34.4+k3s1`

## Label-gated execution
Upgrades do not run until labels are added.
This is intentional to enforce:
- control-plane first
- one worker at a time
- manual operator checkpoint between waves

## Preflight
```bash
# Ensure all workers are schedulable before rollout
kubectl uncordon node01
kubectl get nodes
```

### Trigger control-plane upgrade
```bash
kubectl label node controlplane upgrade-server=active --overwrite
```

### Clear control-plane trigger label
```bash
kubectl label node controlplane upgrade-server-
```

### Trigger one worker upgrade
```bash
kubectl label node <worker-node> upgrade-wave=active --overwrite
```

### Clear worker trigger label
```bash
kubectl label node <worker-node> upgrade-wave-
```

## Recommended worker order
1. `node02`
2. `node04`
3. `node01`
4. `node03`

## Monitor progress
```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs,pods
kubectl get nodes -o wide
```

## Health checks between worker waves
```bash
kubectl get pods -A
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
```

## Master wave note
- Single control-plane upgrade can briefly interrupt Kubernetes API responses.
- Workload traffic should still be observed through app/DB probe checks in:
  - `docs/k3s-system-upgrade-controller-upgrade-plan.md`
- If `apply-server-plan` is `Pending` with `untolerated taint {node-role.kubernetes.io/control-plane}`,
  ensure `server-plan` includes control-plane tolerations from `plans.yaml` and re-sync ArgoCD.
