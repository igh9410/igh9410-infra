# K3s Upgrade Plan via System Upgrade Controller (GitOps)

Date: 2026-03-02

## 1. Scope
- Upgrade mechanism: Rancher System Upgrade Controller (SUC)
- Cluster shape: 1 control-plane (`controlplane`) + 4 workers (`node01`..`node04`)
- Target version (pinned): `v1.34.4+k3s1`
- Git source for plans: `infrastructure/system-upgrade-controller/plans.yaml`
- Quick command reference: `infrastructure/system-upgrade-controller/README.md`

## 2. What is pinned in Git
`server-plan`:
- `version: v1.34.4+k3s1`
- `concurrency: 1`
- `cordon: true`
- Selector: control-plane nodes + `upgrade-server=active`

`agent-plan`:
- `version: v1.34.4+k3s1`
- `concurrency: 1`
- `cordon: true`
- `prepare: server-plan` (workers wait until server plan completes)
- Selector: non-control-plane nodes + `upgrade-wave=active`

Important: upgrades are not fully automatic. They are label-gated on purpose.

## 3. Rollout Steps
1. Sync ArgoCD app `system-upgrade-controller` so latest plans are applied.
2. Confirm SUC objects exist:

```bash
kubectl -n system-upgrade get deploy,pods
kubectl -n system-upgrade get plans -o wide
```

3. Upgrade the control-plane node first by adding label:

```bash
kubectl label node controlplane upgrade-server=active --overwrite
```

4. Monitor until control-plane finishes and returns `Ready` with target version:

```bash
kubectl -n system-upgrade get jobs,pods -w
kubectl get node controlplane -o wide
```

5. Clear control-plane trigger label:

```bash
kubectl label node controlplane upgrade-server-
```

6. Upgrade workers one by one. Recommended order:
   1. `node02`
   2. `node04`
   3. `node01`
   4. `node03`

7. For each worker, run this cycle:

```bash
# Trigger exactly one worker
kubectl label node <worker-node> upgrade-wave=active --overwrite

# Monitor SUC job and node version/readiness
kubectl -n system-upgrade get jobs,pods -w
kubectl get node <worker-node> -o wide

# Clear label before next worker
kubectl label node <worker-node> upgrade-wave-
```

8. After each worker, verify apps and databases before continuing:

```bash
kubectl get pods -A
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
kubectl get pods -n prod-cnpg-database -o wide
kubectl get pods -n cnpg-database -o wide
```

## 4. Cautions
- Single control-plane means brief API interruption is expected during `controlplane` upgrade.
- Keep worker `concurrency: 1` (already configured) to avoid multi-node disruption.
- `cordon: true` may leave node cordoned on failure. Fix cause, then:

```bash
kubectl uncordon <node>
```

- Do not set a lower version than currently running; SUC will fail downgrade attempts and leave nodes cordoned.
- SUC jobs are privileged (host namespaces + host root mount). Keep `system-upgrade` namespace access restricted.

## 5. Completion Criteria
- `kubectl get nodes -o wide` shows all nodes on `v1.34.4+k3s1`
- All nodes are `Ready` and schedulable as expected
- `kubectl get pods -A` has no broken workloads
- CNPG clusters show full ready instance counts and healthy replication
