# Commands Log 03: GitOps Repo and Documentation Work

Date: 2026-03-02  
Repository: `igh9410-infra`

This file lists key repository-side commands executed while preparing manifests and documentation.

## Repo inspection

```bash
git status --short
rg --files docs infrastructure/system-upgrade-controller argocd/infra-apps | sort
sed -n '1,260p' docs/k3s-system-upgrade-controller-upgrade-plan.md
sed -n '1,260p' infrastructure/system-upgrade-controller/README.md
sed -n '1,260p' infrastructure/system-upgrade-controller/plans.yaml
sed -n '1,260p' argocd/infra-apps/system-upgrade-controller.yaml
```

## Render/validation

```bash
kubectl kustomize infrastructure/system-upgrade-controller >/tmp/suc-render.yaml && echo OK
```

## Additional references and diffs

```bash
sed -n '1,320p' docs/k3s-upgrade-progress-summary.md
sed -n '1,340p' docs/k3s-upgrade-v1.33-to-v1.34-runbook.md
git diff -- docs/k3s-system-upgrade-controller-upgrade-plan.md infrastructure/system-upgrade-controller/README.md docs/k3s-upgrade-progress-summary.md infrastructure/system-upgrade-controller/plans.yaml | sed -n '1,320p'
rg -n "server-plan|control-plane" docs/k3s-system-upgrade-controller-upgrade-plan.md infrastructure/system-upgrade-controller/README.md
```

