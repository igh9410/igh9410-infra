# K3s Upgrade Plan via System Upgrade Controller (GitOps)

## Scope
- Upgrade mechanism: Rancher System Upgrade Controller (SUC)
- Target version (pinned): `v1.34.4+k3s1`
- Plans source: `infrastructure/system-upgrade-controller/plans.yaml`
- Cluster shape: 1 control-plane + 4 workers

## What is configured in Git
- `server-plan`
  - Targets nodes with `node-role.kubernetes.io/control-plane`
  - `concurrency: 1`
  - `cordon: true`
  - `version: v1.34.4+k3s1`
- `agent-plan`
  - Targets worker nodes only (`control-plane` label does not exist)
  - Additional selector requires `upgrade-wave=active`
  - `concurrency: 1`
  - `cordon: true`
  - `prepare: server-plan` (workers wait until server plan is complete)
  - `version: v1.34.4+k3s1`

## Execution model
1. Commit and sync the SUC plans through ArgoCD.
2. Control-plane upgrade starts automatically (single node).
3. Workers do not start automatically until you label exactly one worker with `upgrade-wave=active`.
4. Repeat one worker at a time.

## Worker order (recommended)
Current DB primaries are concentrated on `node03`, so keep it last.

1. `node02`
2. `node04`
3. `node01`
4. `node03`

## Commands to run during rollout
Check controller/plans:

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs,pods
kubectl get nodes -o wide
```

Trigger one worker:

```bash
kubectl label node <worker-node> upgrade-wave=active --overwrite
```

Monitor completion for that node:

```bash
kubectl -n system-upgrade get jobs -w
kubectl get node <worker-node> -o wide
```

Remove label before moving to next worker:

```bash
kubectl label node <worker-node> upgrade-wave-
```

## Critical cautions
- Single control-plane means temporary API interruption is expected while server upgrades.
- SUC jobs are privileged (host namespaces and host root mount). Restrict write access to `system-upgrade` resources.
- `cordon: true` can leave a node cordoned if a plan fails. Manually uncordon after fixing root cause:
  - `kubectl uncordon <node>`
- Do not set a lower `version` than current node version; k3s-upgrade blocks downgrades and leaves nodes cordoned.
- Keep worker concurrency at `1` (already set) to minimize disruption with local-path stateful workloads.
- Before upgrading `node01`, if it is still `SchedulingDisabled` from earlier operations, uncordon it first.

## DB safety checks between worker waves
Run after each worker:

```bash
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
kubectl get pods -n prod-cnpg-database -o wide
kubectl get pods -n cnpg-database -o wide
```

Proceed to next worker only when all clusters are healthy and full ready.
