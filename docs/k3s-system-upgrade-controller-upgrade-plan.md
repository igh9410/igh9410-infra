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
- Tolerates control-plane taints (`node-role.kubernetes.io/control-plane` and `node-role.kubernetes.io/master`)
- Selector: control-plane nodes + `upgrade-server=active`

`agent-plan`:
- `version: v1.34.4+k3s1`
- `concurrency: 1`
- `cordon: true`
- `prepare: server-plan` (workers wait until server plan completes)
- Selector: non-control-plane nodes + `upgrade-wave=active`

Important: upgrades are not fully automatic. They are label-gated on purpose.

## 3. Rollout Steps
1. Preflight node scheduling state (required):

```bash
# node01 is currently expected to be uncordoned before rollout
kubectl get nodes
kubectl uncordon node01
kubectl get nodes
```

2. Sync ArgoCD app `system-upgrade-controller` so latest plans are applied.
3. Confirm SUC objects exist:

```bash
kubectl -n system-upgrade get deploy,pods
kubectl -n system-upgrade get plans -o wide
```

4. Upgrade the control-plane node first by adding label:

```bash
kubectl label node controlplane upgrade-server=active --overwrite
```

5. Monitor until control-plane finishes and returns `Ready` with target version:

```bash
kubectl -n system-upgrade get jobs,pods -w
kubectl get node controlplane -o wide
```

6. Clear control-plane trigger label:

```bash
kubectl label node controlplane upgrade-server-
```

7. Upgrade workers one by one. Recommended order:
   1. `node02`
   2. `node04`
   3. `node01`
   4. `node03`

8. For each worker, run this cycle:

```bash
# Trigger exactly one worker
kubectl label node <worker-node> upgrade-wave=active --overwrite

# Monitor SUC job and node version/readiness
kubectl -n system-upgrade get jobs,pods -w
kubectl get node <worker-node> -o wide

# Clear label before next worker
kubectl label node <worker-node> upgrade-wave-
```

9. After each worker, verify apps and databases before continuing:

```bash
kubectl get pods -A
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
kubectl get pods -n prod-cnpg-database -o wide
kubectl get pods -n cnpg-database -o wide
```

## 4. Cautions
- Single control-plane means brief Kubernetes API disruption is expected during `controlplane` upgrade.
- Keep worker `concurrency: 1` (already configured) to avoid multi-node disruption.
- `cordon: true` may leave node cordoned on failure. Fix cause, then:

```bash
kubectl uncordon <node>
```

- Do not set a lower version than currently running; SUC will fail downgrade attempts and leave nodes cordoned.
- SUC jobs are privileged (host namespaces + host root mount). Keep `system-upgrade` namespace access restricted.

## 5. Downtime Verification Procedure (Apps + DB)
Absolute zero downtime cannot be guaranteed in advance.  
Use continuous probes and confirm zero failed checks in logs during all worker waves and the control-plane wave.

1. Start continuous app probes before first upgrade wave:

```bash
kubectl -n dev run app-probe-dev --image=curlimages/curl:8.12.1 --restart=Never --command -- \
  sh -c 'while true; do ts=$(date -Iseconds); for u in http://gramnuri-api.dev.svc.cluster.local http://gramnuri-web.dev.svc.cluster.local; do c=$(curl -sS -o /dev/null -w "%{http_code}" "$u" || echo 000); echo "$ts $u code=$c"; done; sleep 2; done'

kubectl -n prod run app-probe-prod --image=curlimages/curl:8.12.1 --restart=Never --command -- \
  sh -c 'while true; do ts=$(date -Iseconds); for u in http://gramnuri-api.prod.svc.cluster.local http://gramnuri-web.prod.svc.cluster.local http://artskorner-api.prod.svc.cluster.local; do c=$(curl -sS -o /dev/null -w "%{http_code}" "$u" || echo 000); echo "$ts $u code=$c"; done; sleep 2; done'
```

2. Watch probe logs while upgrading nodes:

```bash
kubectl -n dev logs -f pod/app-probe-dev
kubectl -n prod logs -f pod/app-probe-prod
```

3. Validate DB availability after each node wave:

```bash
kubectl get clusters.postgresql.cnpg.io -A -o wide
kubectl -n prod-cnpg-database get pods -o wide
kubectl -n cnpg-database get pods -o wide
```

4. Validate prod DB synchronous replication after each node wave:

```bash
kubectl -n prod-cnpg-database exec -i $(kubectl -n prod-cnpg-database get cluster prod-gramnuri-db-cluster -o jsonpath='{.status.currentPrimary}') -- \
  psql -U postgres -d postgres -Atc "show synchronous_standby_names; select application_name||':'||sync_state from pg_stat_replication order by application_name;"

kubectl -n prod-cnpg-database exec -i $(kubectl -n prod-cnpg-database get cluster prod-artskorner-db-cluster -o jsonpath='{.status.currentPrimary}') -- \
  psql -U postgres -d postgres -Atc "show synchronous_standby_names; select application_name||':'||sync_state from pg_stat_replication order by application_name;"
```

Expected:
- app probes keep returning HTTP `200` (no `000`, `502`, `503`, `504`)
- CNPG clusters remain healthy and return to full ready instance count
- synchronous replication stays enabled (`ANY 1 (...)` and standbys in `quorum`)

5. Cleanup probes after upgrade:

```bash
kubectl -n dev delete pod app-probe-dev
kubectl -n prod delete pod app-probe-prod
```

## 6. Completion Criteria
- `kubectl get nodes -o wide` shows all nodes on `v1.34.4+k3s1`
- All nodes are `Ready` and schedulable as expected
- `kubectl get pods -A` has no broken workloads
- CNPG clusters show full ready instance counts and healthy replication

## 7. Observed Impact Report
- Detailed measured downtime/impact stats are documented separately:
  - `docs/k3s-failover-impact-report.md`
