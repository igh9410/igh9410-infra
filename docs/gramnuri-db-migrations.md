# gramnuri-api database migrations

Schema migrations for `gramnuri_db` run automatically as part of each gramnuri-api
deployment instead of `make migrate-up` from a laptop.

## How it works

| Piece | Where | Notes |
| --- | --- | --- |
| Migration-only role `gramnuri_migrator` | `argocd/values/{dev,prod}-gramnuri-db.yaml` (`cluster.roles`) | CNPG managed role: login, no superuser/createrole/createdb, connection limit 3. Owns the tables and sequences in `public` and has `CREATE` on it. The database and schema stay owned by `cluster_admin`, so it cannot drop them. |
| Role password | `apps/gramnuri-api/terraform/{dev,prod}/db-migrator.tf` | `random_password` written to `gramnuri-migrator-credentials` (basic-auth, CNPG namespace) and `gramnuri-migrator-secrets` (`MIGRATION_DATABASE_URL`, app namespace). |
| Migration Job | `apps/gramnuri-api/components/db-migration/` | ArgoCD `PreSync` hook running `gramnuri-api migrate up` from the same image tag as the Deployment. |
| API role `gramnuri_db_user` | unchanged | DML only (SELECT/INSERT/UPDATE/DELETE). Gets access to new tables through default privileges set in the handover script. |

Sync flow for `dev-gramnuri-api` (auto-sync) and `prod-gramnuri-api` (manual sync):

1. The deploy workflow commits a new image tag to `overlays/<env>/kustomization.yaml`.
2. ArgoCD starts a sync. The `PreSync` Job runs the migrations embedded in that image.
3. Only if the Job succeeds does ArgoCD apply the Deployment. A failed Job fails the sync and the running pods keep serving.

The previous release keeps serving while migrations run, so migrations must be
backward-compatible (expand/contract): add columns/tables first, remove them in a later release.

Auto-sync does not retry a failed sync for the same Git revision. After fixing a
failed migration, push a new commit or press Sync.

## One-time setup per environment

Order matters. Do dev first, then prod.

1. Merge the gramnuri PR that adds the `migrate` subcommand, and let the new image reach the environment
   (dev: automatic; prod: GitHub release, then manual sync). The image must contain the subcommand before the Job is added.
2. Merge the infra PR that adds the role and Terraform (this file's PR).
   ArgoCD syncs `<env>-gramnuri-db` and CNPG creates `gramnuri_migrator` once the Secret exists.
3. Create the secrets:

   ```sh
   cd apps/gramnuri-api/terraform/<env>
   terraform init -backend-config=backend.conf
   terraform plan    # expect only: random_password.db_migrator + 2 kubernetes_secret
   terraform apply
   ```

4. Confirm the role exists and is reconciled:

   ```sh
   K="kubectl --context tailscale-operator-1.taild7ce30.ts.net"
   NS=cnpg-database   # prod: prod-cnpg-database
   $K -n $NS get cluster <env>-gramnuri-db-cluster -o jsonpath='{.status.managedRolesStatus}'
   ```

5. Hand over ownership of the existing tables and sequences from `cluster_admin` and grant `CREATE` on `public` (superuser, idempotent):

   ```sh
   POD=$($K -n $NS get pods -l cnpg.io/instanceRole=primary -o name | head -1)
   $K -n $NS exec -i $POD -c postgres -- psql -d gramnuri_db -v ON_ERROR_STOP=1 \
     < scripts/gramnuri-db-migrator-handover.sql
   ```

   This cannot be a goose migration: taking ownership away from another role requires superuser.
   It deliberately avoids `REASSIGN OWNED`, which would also move `artskorner_db` in the prod cluster.
   A future migration that runs `CREATE SCHEMA` additionally needs `GRANT CREATE ON DATABASE gramnuri_db TO gramnuri_migrator`.

6. Merge the infra PR that adds the `db-migration` component to the overlays.
   For prod, sync `applications-app-of-apps` and then `prod-gramnuri-api` manually.

After the handover, do not run migrations against dev/prod as `cluster_admin`
(`make migrate-up` with the old `.env` credentials). It no longer owns the tables,
so `ALTER TABLE` on existing tables fails, but because it still owns schema `public`
it can create tables (owned by `cluster_admin`, which the migrator then cannot alter)
and drop tables. A partial run leaves ownership drift. Keep `cluster_admin` as a
break-glass admin account only.

To check or run migrations from a laptop, use the migrator credentials over Tailscale:

```sh
MIGRATION_DATABASE_URL='postgresql://gramnuri_migrator:<password>@dev-gramnuri-db.taild7ce30.ts.net:5432/gramnuri_db' \
  go run ./cmd/gramnuri-api migrate status
```

The password is in the `gramnuri-migrator-credentials` Secret (CNPG namespace) or the Terraform state.

## Operating

```sh
K="kubectl --context tailscale-operator-1.taild7ce30.ts.net"
# Logs of the last migration run (kept until the next sync)
$K -n dev logs job/gramnuri-api-db-migration
# Status/version without deploying, using the same credentials as the Job
$K -n dev run gramnuri-migrate-status --rm -i --restart=Never \
  --image=ghcr.io/igh9410/gramnuri-api:<tag> \
  --overrides='{"spec":{"imagePullSecrets":[{"name":"ghcr-image-pull-secrets"}],"containers":[{"name":"m","image":"ghcr.io/igh9410/gramnuri-api:<tag>","args":["migrate","status"],"envFrom":[{"secretRef":{"name":"gramnuri-migrator-secrets"}}]}]}}'
```

Rotate the migrator password with `terraform apply -replace=random_password.db_migrator`.
CNPG picks up the new password through the `cnpg.io/reload` label on the Secret.
