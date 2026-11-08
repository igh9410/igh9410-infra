# gramnuri-secrets is no longer managed here. It is synced from GCP Secret
# Manager (gramnuri-api-<env>) by apps/gramnuri-api/base/externalsecret.yaml.
# The provider stays for cluster resources still managed by this module.
provider "kubernetes" {
  config_path = var.kubeconfig_path
}
