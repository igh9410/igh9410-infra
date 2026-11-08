#!/usr/bin/env bash
# Create (or rotate) the Kubernetes Secrets for the migration-only Postgres role
# gramnuri_migrator. The role itself is a CNPG managed role declared in
# argocd/values/<env>-gramnuri-db.yaml (cluster.roles).
#
#   scripts/gramnuri-db-migrator-secrets.sh <dev|prod> [--rotate] [--dry-run]
#
# Writes two Secrets with the same password:
#   <cnpg-namespace>/gramnuri-migrator-credentials  basic-auth, read by CNPG to set
#                                                   the role password (cnpg.io/reload)
#   <env>/gramnuri-migrator-secrets                 MIGRATION_DATABASE_URL for the
#                                                   PreSync migration Job
#
# The password is generated locally and never written to Git, Terraform state,
# stdout or process arguments. Re-running without --rotate reuses the existing
# password, so the script is safe to run again (e.g. to recreate the app Secret).
# --dry-run validates both Secrets against the API server without saving them.
#
# Env: KUBE_CONTEXT (default: tailscale-operator-1.taild7ce30.ts.net)
set -euo pipefail

usage() {
  echo "usage: $0 <dev|prod> [--rotate] [--dry-run]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
env="$1"
shift
rotate=false
dry_run=()
for arg in "$@"; do
  case "$arg" in
    --rotate) rotate=true ;;
    --dry-run) dry_run=(--dry-run=server) ;;
    *) usage ;;
  esac
done

case "$env" in
  dev) db_namespace="cnpg-database" ;;
  prod) db_namespace="prod-cnpg-database" ;;
  *) usage ;;
esac

role="gramnuri_migrator"
role_secret="gramnuri-migrator-credentials"
job_secret="gramnuri-migrator-secrets"
db_host="${env}-gramnuri-db-cluster-rw.${db_namespace}.svc.cluster.local"
kubectl=(kubectl --context "${KUBE_CONTEXT:-tailscale-operator-1.taild7ce30.ts.net}")

workdir="$(mktemp -d)"
chmod 700 "$workdir"
trap 'rm -rf "$workdir"' EXIT

existing="$("${kubectl[@]}" -n "$db_namespace" get secret "$role_secret" \
  -o jsonpath='{.data.password}' --ignore-not-found)"

if [[ -n "$existing" && "$rotate" == false ]]; then
  echo "Reusing the existing password from ${db_namespace}/${role_secret} (pass --rotate to replace it)."
  base64 -d <<<"$existing" >"$workdir/password"
else
  # 40 alphanumeric characters: safe to embed in a connection URL without escaping.
  (LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom || true) | head -c 40 >"$workdir/password"
  echo "Generated a new password."
fi
[[ "$(wc -c <"$workdir/password")" -ge 32 ]] || { echo "password generation failed" >&2; exit 1; }

printf '%s' "$role" >"$workdir/username"
printf 'postgresql://%s:%s@%s:5432/gramnuri_db?sslmode=require' \
  "$role" "$(cat "$workdir/password")" "$db_host" >"$workdir/MIGRATION_DATABASE_URL"

# CNPG requires a basic-auth Secret whose username matches the role name.
"${kubectl[@]}" -n "$db_namespace" create secret generic "$role_secret" \
  --type=kubernetes.io/basic-auth \
  --from-file=username="$workdir/username" \
  --from-file=password="$workdir/password" \
  --dry-run=client -o yaml |
  "${kubectl[@]}" label --local -f - "cnpg.io/reload=true" -o yaml |
  "${kubectl[@]}" apply "${dry_run[@]}" -f -

"${kubectl[@]}" -n "$env" create secret generic "$job_secret" \
  --from-file=MIGRATION_DATABASE_URL="$workdir/MIGRATION_DATABASE_URL" \
  --dry-run=client -o yaml |
  "${kubectl[@]}" apply "${dry_run[@]}" -f -

if [[ ${#dry_run[@]} -eq 0 ]]; then
  echo "Done. CNPG applies the password to role ${role} on its next reconcile."
fi
