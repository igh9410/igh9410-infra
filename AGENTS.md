# AGENTS.md

## Repository Structure

This repository is a GitOps infrastructure repo built around ArgoCD, Helm, Kustomize, and Terraform.

Use this layout as the default mental model:

- `apps/` for application deployments
- `argocd/apps/` and `argocd/infra-apps/` for ArgoCD Applications
- `argocd/values/` for Helm values files
- `infrastructure/` for cluster-level infrastructure configuration
- `monitoring/` for Kustomize-managed monitoring resources

Application directories typically follow this pattern:

- `apps/{app}/base/` for shared manifests
- `apps/{app}/overlays/` for environment-specific overlays
- `apps/{app}/terraform/` for app-specific infrastructure such as secrets or DNS

## Kustomize And Helm

Use Kustomize for repository-owned Kubernetes resources and CRDs that should be managed independently from Helm chart lifecycle.

Use Helm for third-party applications and complex templated deployments, especially when the chart already models the resource relationships well.

Every Kustomize directory must include a `kustomization.yaml`. Prefer descriptive kebab-case filenames, keep related resources together, and use one resource type per file when practical.

## ArgoCD Conventions

For each independently managed component, keep a corresponding ArgoCD Application under `argocd/apps/` or `argocd/infra-apps/`.

Follow the existing repo patterns for ArgoCD Application definitions:

- `project: default`
- automated sync with `prune: true` and `selfHeal: true`
- `revisionHistoryLimit: 10`

Match the existing source type used by the component:

- Kustomize-backed repo paths for repo-managed manifests
- Helm chart sources plus values files in `argocd/values/` for Helm-managed components

## Secrets

Never commit secrets to Git.

Use Terraform or external secret creation workflows to create Kubernetes Secrets, and reference those Secrets from manifests. Do not hardcode credentials, tokens, webhook URLs, or other secret values in YAML.

## Namespaces And Naming

Use namespace-based environment separation instead of `namePrefix` for applications.

Application resources should usually keep the plain app name in each environment namespace. For example, use `gramnuri-api` in `dev` and `prod`, rather than `dev-gramnuri-api` or `prod-gramnuri-api`.

Keep these namespace conventions unless there is an established exception:

- `monitoring` for monitoring stack components
- `dev` for development applications
- `prod` for production applications
- `argocd` for the ArgoCD control plane
- `cnpg-database` and `prod-cnpg-database` for CNPG clusters

## Monitoring Conventions

Manage custom Alertmanager, Loki, and Grafana resources under `monitoring/` with Kustomize.

Follow these repo conventions:

- Alertmanager custom resources belong in `monitoring/alertmanager/`
- Loki rules belong in `monitoring/loki/`
- Grafana dashboards and datasources belong in `monitoring/grafana/`
- Grafana dashboard ConfigMaps must include `grafana_dashboard: "1"`
- Grafana datasource ConfigMaps must include `grafana_datasource: "1"`

When adding alerting or log-query configuration, document non-obvious regex, PromQL, or LogQL expressions with concise comments.

## YAML Conventions

Use 2-space indentation in YAML.

Prefer double-quoted strings in YAML, use `|` for multi-line strings such as PromQL or LogQL, and add brief comments where the configuration is not obvious.

## Custom Application Manifests

For custom applications in this repository, do not use `exec`-based `preStop` hooks such as `/bin/sh -c "sleep 30"`.

Several custom application images are built as multi-stage images and run as distroless containers, so shell binaries like `/bin/sh` and `sleep` may not exist in the runtime image.

When a shutdown delay is needed, use the Kubernetes lifecycle `sleep` action instead:

```yaml
lifecycle:
  preStop:
    sleep:
      seconds: 30
terminationGracePeriodSeconds: 60
```

Apply this convention to all custom applications under `apps/` unless a service has a documented exception.

## Multi-Agent Git Workflow

When multiple agents work on this repository, each agent must use a separate branch for its own task.

Do not have multiple agents modify the same files in parallel. Split work so each agent owns a disjoint file set, and avoid touching files that another agent is already editing.

If a task would require editing files that are already in another agent's scope, re-scope the task first instead of creating overlapping commits.

The recommended setup for parallel agent work is one coordinator session plus one terminal session per agent task, with each agent working on its own branch and preferably its own `git worktree`.

Do not run multiple editing agents against the same checkout. Sharing one working tree is acceptable for read-only investigation, but concurrent file edits must happen in separate branches and separate worktrees.
