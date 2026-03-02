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

## Step 8. Upgrade Mechanism Migration to SUC (Completed in Git)
- Replaced manual per-node upgrade approach with Rancher System Upgrade Controller (SUC) via GitOps.
- Added SUC install manifests under:
  - `infrastructure/system-upgrade-controller/crd.yaml`
  - `infrastructure/system-upgrade-controller/system-upgrade-controller.yaml`
  - `infrastructure/system-upgrade-controller/kustomization.yaml`
- Added ArgoCD infra application:
  - `argocd/infra-apps/system-upgrade-controller.yaml`

## Step 9. Pinned and Label-Gated Upgrade Plans (Completed in Git)
- Added pinned plans:
  - `infrastructure/system-upgrade-controller/plans.yaml`
- Plan properties:
  - `version: v1.34.4+k3s1` (both server and agent plans)
  - `concurrency: 1` and `cordon: true`
  - Agent plan includes `prepare: server-plan`
- Manual gating labels added to prevent unintended auto-rollout:
  - Control-plane gate: `upgrade-server=active`
  - Worker gate: `upgrade-wave=active` (apply to one worker at a time)

## Step 10. Documentation Added (Completed in Git)
- Detailed SUC runbook:
  - `docs/k3s-system-upgrade-controller-upgrade-plan.md`
- Operator quick-reference:
  - `infrastructure/system-upgrade-controller/README.md`

## Step 11. Downtime Verification Procedure Documented (Completed in Git)
- Added explicit preflight to uncordon `node01` before upgrade waves.
- Added explicit note: control-plane wave can briefly interrupt Kubernetes API.
- Added concrete app uptime probes (dev/prod service HTTP checks).
- Added DB health and synchronous replication verification checks between node waves.
