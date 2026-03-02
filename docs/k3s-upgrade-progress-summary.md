# K3s Upgrade Preparation Summary (So Far)

Date: 2026-03-02  
Cluster context: `default`

## Step 1. Baseline Assessment (Completed)
- Confirmed cluster version/state:
  - Kubernetes server: `v1.33.5+k3s1`
  - Topology: 1 control-plane + 4 workers
  - All nodes `Ready`
- Confirmed workloads:
  - App namespaces: `dev`, `prod`
  - CNPG clusters healthy (`dev` 2/2, `prod` 3/3 each)
  - Storage class is `local-path` (important for node-drain behavior)

## Step 2. App HA GitOps Hardening (Completed and Synced)
- Added app `PodDisruptionBudget` (`minAvailable: 1`) for:
  - `gramnuri-api`, `gramnuri-web`, `artskorner-api`
- Increased `dev` app replicas to 2:
  - `dev/gramnuri-api`, `dev/gramnuri-web`
- Added app pod anti-affinity + topology spread (`kubernetes.io/hostname`) in app base deployments.
- Result after sync:
  - `dev`: API/Web = `2/2` available
  - `prod`: all apps = `2/2` available
  - App PDBs present in both `dev` and `prod`

## Step 3. Infra/CNPG GitOps Corrections (Completed and Synced)
- Fixed ArgoCD infra app filename typo:
  - `argocd/infra-apps/prod-artskorner-db .yaml` -> `argocd/infra-apps/prod-artskorner-db.yaml`
- CNPG values updated:
  - `topologyKey` changed from `topology.kubernetes.io/zone` to `kubernetes.io/hostname` (cluster had no zone labels)
  - `dev` WAL storage class made explicit: `local-path`
- Result after sync:
  - CNPG live specs now show `topologyKey=kubernetes.io/hostname`
  - CNPG clusters are `Ready=True`, `LastBackupSucceeded=True`

## Step 4. Post-Sync Health Verification (Completed)
- ArgoCD Applications: all relevant apps `Synced` + `Healthy`
- Pods:
  - No non-running pods found cluster-wide
  - App and DB pods running after reconciliation
- HA posture:
  - App-level HA features (replicas + PDB + spread) are active
  - CNPG PDBs active and clusters healthy

## Step 5. Additional Hardening Requested (Done in Git, Pending Sync)
- Enabled synchronous replication for production databases:
  - `argocd/values/prod-gramnuri-db.yaml`
  - `argocd/values/prod-artskorner-db.yaml`
  - Added:
    - `cluster.postgresql.synchronous.method: any`
    - `cluster.postgresql.synchronous.number: 1`
- Updated runbook with explicit replica rebalancing procedure for `prod-gramnuri-db` and node01 drain decision:
  - `docs/k3s-upgrade-v1.33-to-v1.34-runbook.md`

Current live check shows these sync-replica settings are still pending:
- `synchronous_standby_names` is empty on both prod primaries
- `pg_stat_replication` shows both standbys as `async`

## Step 6. Current Known HA Gap
- `prod-gramnuri-db-cluster` currently has 2 replicas on `node01` (primary on `node03`), so node-level spread is not ideal yet.

## Step 7. Remaining Actions (Next)
1. Sync ArgoCD apps:
   - `prod-gramnuri-db`
   - `prod-artskorner-db`
2. Rebalance one non-primary `prod-gramnuri-db` replica off `node01`:
   - Cordon `node01`
   - Delete one non-primary pod + its PVC/WAL PVC (example: `prod-gramnuri-db-cluster-3`)
   - Wait for `3/3` and confirm placement on a different node
   - Uncordon `node01`
3. Re-verify before k3s upgrade:
   - CNPG sync settings (`synchronous_standby_names`, standby `sync_state`)
   - CNPG pod placement
   - App and DB readiness/PDBs
