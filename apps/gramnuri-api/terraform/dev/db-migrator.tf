# Credentials for the migration-only Postgres role "gramnuri_migrator".
#
# The role itself is declared as a CNPG managed role in
# argocd/values/<env>-gramnuri-db.yaml (cluster.roles). CNPG reads the password
# from the basic-auth Secret below, in the database cluster's namespace.
# The same password is exposed to the PreSync migration Job in the app
# namespace as MIGRATION_DATABASE_URL. Rotate with: terraform apply -replace=random_password.db_migrator

locals {
  db_migrator_role   = "gramnuri_migrator"
  db_namespace       = var.environment == "prod" ? "prod-cnpg-database" : "cnpg-database"
  db_rw_host         = "${var.environment}-gramnuri-db-cluster-rw.${local.db_namespace}.svc.cluster.local"
  db_migrator_secret = "gramnuri-migrator-credentials"
}

resource "random_password" "db_migrator" {
  length = 40
  # Alphanumeric only, so the password is safe to embed in a connection URL.
  special = false
}

# Consumed by CNPG (cluster.roles[].passwordSecret). The reload label makes the
# operator re-apply the password when this Secret changes.
resource "kubernetes_secret" "db_migrator_role" {
  metadata {
    name      = local.db_migrator_secret
    namespace = local.db_namespace
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = local.db_migrator_role
    password = random_password.db_migrator.result
  }
}

# Consumed by the gramnuri-api-db-migration Job (envFrom).
resource "kubernetes_secret" "db_migrator_job" {
  metadata {
    name      = "gramnuri-migrator-secrets"
    namespace = var.environment
  }

  type = "Opaque"

  data = {
    MIGRATION_DATABASE_URL = "postgresql://${local.db_migrator_role}:${random_password.db_migrator.result}@${local.db_rw_host}:5432/gramnuri_db?sslmode=require"
  }
}
