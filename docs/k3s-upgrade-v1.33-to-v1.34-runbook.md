# K3s Upgrade Runbook: `v1.33.5+k3s1` -> `v1.34.x+k3s1`

> Note: actual execution is now done via System Upgrade Controller (GitOps).
> Use `docs/k3s-system-upgrade-controller-upgrade-plan.md` as the primary upgrade procedure.

## 1. Scope
- Cluster context: `default`
- Topology: 1 control-plane (`controlplane`) + 4 workers (`node01`..`node04`)
- Workloads: ArgoCD-managed Go APIs + CloudNativePG Postgres clusters
- Goal: best-effort no application downtime during a minor k3s upgrade

## 2. Current Baseline (captured 2026-03-02)
- Kubernetes client: `v1.33.2`
- Kubernetes server: `v1.33.5+k3s1`
- All nodes are `Ready`
- CNPG clusters:
  - `cnpg-database/dev-gramnuri-db-cluster`: 2/2 ready, primary `dev-gramnuri-db-cluster-1`
  - `prod-cnpg-database/prod-artskorner-db-cluster`: 3/3 ready, primary `prod-artskorner-db-cluster-1`
  - `prod-cnpg-database/prod-gramnuri-db-cluster`: 3/3 ready, primary `prod-gramnuri-db-cluster-1`
- StorageClass: `local-path` only (important for drain behavior with stateful pods)

## 3. GitOps Changes Required Before Upgrade
These are included in this branch/worktree and must be synced by ArgoCD before upgrading nodes.

### 3.1 Availability hardening for app Deployments
- Increased `dev` replicas to 2:
  - `apps/gramnuri-api/overlays/dev/deployment-patch.yaml`
  - `apps/gramnuri-web/overlays/dev/deployment-patch.yaml`
- Added app-level `PodDisruptionBudget` (`minAvailable: 1`) to:
  - `apps/gramnuri-api/base/pdb.yaml`
  - `apps/gramnuri-web/base/pdb.yaml`
  - `apps/artskorner-api/base/pdb.yaml`
- Added pod spreading hints (preferred anti-affinity + topology spread by hostname) to:
  - `apps/gramnuri-api/base/deployment.yaml`
  - `apps/gramnuri-web/base/deployment.yaml`
  - `apps/artskorner-api/base/deployment.yaml`

### 3.2 Sync order
1. Merge/push to `main`.
2. Sync these application ArgoCD apps:
   - `dev-gramnuri-api`
   - `dev-gramnuri-web`
   - `prod-gramnuri-api`
   - `prod-gramnuri-web`
   - `prod-artskorner-api`
3. Sync these infra ArgoCD apps (CNPG value updates):
   - `dev-gramnuri-db`
   - `prod-gramnuri-db`
   - `prod-artskorner-db`
4. Verify:

```bash
kubectl -n dev get deploy gramnuri-api gramnuri-web
kubectl -n prod get deploy gramnuri-api gramnuri-web artskorner-api
kubectl get pdb -n dev
kubectl get pdb -n prod
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" topologyKey="}{.spec.affinity.topologyKey}{" walSC="}{.spec.walStorage.storageClass}{"\n"}{end}'
```

Expected:
- all listed Deployments have at least 2 replicas
- PDBs exist for all three apps in `dev` and `prod`
- CNPG topology key is `kubernetes.io/hostname` and WAL storage class is explicit

## 4. Pre-Upgrade Safety Checks
Set target version explicitly (replace with exact patch you choose):

```bash
export TARGET_K3S_VERSION="v1.34.x+k3s1"
```

### 4.1 Snapshot current cluster state
```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods -A
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
kubectl get pdb -A
```

### 4.2 Backups
- CNPG: ensure recent successful backups exist, and optionally trigger on-demand backups.
- k3s datastore:
  - If using embedded etcd: `sudo k3s etcd-snapshot save --name pre-k3s-upgrade-$(date +%F-%H%M)`
  - If using sqlite/external DB: take VM snapshot or datastore backup before upgrade.

### 4.3 Temporary freeze
- Avoid app/config changes during upgrade window.
- Pause CI/CD image rollouts until the cluster is fully upgraded.

## 5. Upgrade Strategy
`local-path` storage means DB/monitoring stateful pods are node-affined.  
Do **not** treat all workers the same:
- `node02`, `node04`: normal drain + upgrade.
- `node03`: move CNPG primaries away first, then drain + upgrade.
- `node01`: drain is safe only if `prod-gramnuri-db-cluster` is rebalanced first.

### 5.1 Rebalance `prod-gramnuri-db-cluster` (recommended before upgrade)
Current topology can place two replicas on `node01` because of historical `local-path` PVC pinning.  
Rebuild one non-primary replica from `node01` to spread instances across more nodes.

1. Check current primary and placement:

```bash
kubectl -n prod-cnpg-database get clusters.postgresql.cnpg.io prod-gramnuri-db-cluster -o jsonpath='{.status.currentPrimary}{"\n"}'
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide
```

2. Pick a non-primary replica currently on `node01` (example: `prod-gramnuri-db-cluster-3`).
3. Cordon `node01` temporarily:

```bash
kubectl cordon node01
```

4. Rebuild only that replica (safe for HA, but it recreates replica-local data):

```bash
kubectl -n prod-cnpg-database delete pod prod-gramnuri-db-cluster-3 --wait=true
kubectl -n prod-cnpg-database delete pvc prod-gramnuri-db-cluster-3 prod-gramnuri-db-cluster-3-wal
```

5. Wait for `3/3` ready and verify the rebuilt replica is on a different node:

```bash
kubectl -n prod-cnpg-database get pods -l cnpg.io/cluster=prod-gramnuri-db-cluster -o wide -w
kubectl get clusters.postgresql.cnpg.io -n prod-cnpg-database prod-gramnuri-db-cluster -o jsonpath='{.status.readyInstances}{"/"}{.spec.instances}{" primary="}{.status.currentPrimary}{"\n"}'
```

6. Uncordon `node01`:

```bash
kubectl uncordon node01
```

Recommended order:
1. `node02`
2. `node04`
3. `node03` (after CNPG primary relocation)
4. `node01` (drain if rebalanced, otherwise cordon-only)
5. `controlplane` (last)

## 6. Worker Upgrade Steps
For `node02` and `node04`:

```bash
kubectl cordon <NODE>
kubectl drain <NODE> --ignore-daemonsets --delete-emptydir-data --grace-period=30 --timeout=15m

ssh igh9410@<NODE_IP> "curl -sfL https://get.k3s.io | sudo env INSTALL_K3S_VERSION=${TARGET_K3S_VERSION} sh -"

kubectl wait --for=condition=Ready node/<NODE> --timeout=10m
kubectl uncordon <NODE>
kubectl get node <NODE> -o wide
```

### 6.1 CNPG primary relocation check (before `node03` and `node01`)
Check current primary placement:

```bash
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{"\n"}{end}'
kubectl get pods -n cnpg-database -o wide
kubectl get pods -n prod-cnpg-database -o wide
```

If a primary is on the node you are about to upgrade, run a planned switchover to a ready replica on a different node:

```bash
kubectl -n <NS> get pods -l cnpg.io/cluster=<CLUSTER_NAME> -o wide
kubectl cnpg promote <CLUSTER_NAME> <TARGET_REPLICA_POD_NAME> -n <NS>
```

`<TARGET_REPLICA_POD_NAME>` must be a healthy replica and should not be on the node being drained.

Wait until the cluster is healthy again and primary moved:

```bash
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
```

### 6.2 `node03` (after primary relocation)
```bash
kubectl cordon node03
kubectl drain node03 --ignore-daemonsets --delete-emptydir-data --grace-period=30 --timeout=15m
ssh igh9410@192.168.45.202 "curl -sfL https://get.k3s.io | sudo env INSTALL_K3S_VERSION=${TARGET_K3S_VERSION} sh -"
kubectl wait --for=condition=Ready node/node03 --timeout=10m
kubectl uncordon node03
```

### 6.3 `node01` option A (preferred if rebalanced): normal drain

```bash
kubectl cordon node01
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data --grace-period=30 --timeout=15m
ssh igh9410@192.168.45.200 "curl -sfL https://get.k3s.io | sudo env INSTALL_K3S_VERSION=${TARGET_K3S_VERSION} sh -"
kubectl wait --for=condition=Ready node/node01 --timeout=10m
kubectl uncordon node01
```

### 6.4 `node01` option B (fallback if not rebalanced): cordon-only

```bash
kubectl cordon node01
ssh igh9410@192.168.45.200 "curl -sfL https://get.k3s.io | sudo env INSTALL_K3S_VERSION=${TARGET_K3S_VERSION} sh -"
kubectl wait --for=condition=Ready node/node01 --timeout=10m
kubectl uncordon node01
```

## 7. Control-Plane Upgrade (single server)
Upgrade last:

```bash
ssh igh9410@192.168.45.199 "curl -sfL https://get.k3s.io | sudo env INSTALL_K3S_VERSION=${TARGET_K3S_VERSION} sh -"
```

Notes:
- During control-plane restart, Kubernetes API may be briefly unavailable (expected with single control-plane).
- Existing running workloads should continue.

## 8. Post-Upgrade Validation
```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods -A
kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" primary="}{.status.currentPrimary}{" ready="}{.status.readyInstances}{"/"}{.spec.instances}{"\n"}{end}'
kubectl get pdb -A
```

Success criteria:
- All nodes show target `v1.34.x+k3s1`.
- No `NotReady` nodes.
- CNPG clusters return to full ready instance counts.
- App Deployments remain at desired replicas with Ready pods.

## 9. Rollback / Recovery
If one node upgrade fails:
1. Keep node cordoned.
2. Reinstall previous version on that node:
   - `v1.33.5+k3s1`
3. Restart node service and re-check node readiness.
4. Uncordon only after workloads are healthy.

If control-plane fails to recover:
1. Restore from k3s datastore backup/snapshot.
2. Bring API server back first.
3. Reconcile node versions and re-run post-upgrade validation.
