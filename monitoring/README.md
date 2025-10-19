# Monitoring Configuration

This directory contains Kustomize-managed monitoring configurations that are deployed independently from Helm charts.

## Structure

```
monitoring/
├── alertmanager/          # AlertManager custom configurations
│   ├── kustomization.yaml
│   └── discord-config.yaml
│
├── loki/                  # Loki rules and configurations
│   ├── kustomization.yaml
│   └── loki-rules.yaml
│
└── grafana/               # Grafana dashboards and datasources
    ├── kustomization.yaml
    ├── dashboards/
    │   └── gramnuri-api-dashboard.yaml
    └── datasources/
        └── loki-datasource.yaml
```

## Components

### AlertManager (`alertmanager/`)

Contains AlertmanagerConfig CRDs for routing alerts to external services.

**Current Configurations:**

- `discord-config.yaml` - Routes alerts to Discord webhook
  - Matches: `Http5xxError`, `GoAPIErrorLogged`, `GoAPICriticalError`, `GoAPIPanicDetected`
  - Uses secret: `dev-alarms-webhook-url` (created via Terraform)

**Deployment:**

- Managed by ArgoCD application: `argocd/infra-apps/alertmanager-config.yaml`
- Auto-syncs from Git
- Namespace: `monitoring`

### Loki (`loki/`)

Contains Loki recording rules for log-based alerting.

**Current Rules:**

- `GoAPIErrorLogged` - Detects JSON logs with `level="error"` in gramnuri-api (warning)
- `GoAPICriticalError` - Detects 5xx errors in error logs (critical)
- `GoAPIPanicDetected` - Detects `panic`, `fatal`, or `dpanic` level logs (critical)

**Features:**

- Parses JSON structured logs (Zap logger)
- Extracts `msg` field for alert descriptions
- Uses `sum by (namespace, msg)` for multi-environment support
- Includes error message in Discord notifications

**Note:** Rules use `sum by (namespace)` to match services across all environments (dev, prod, etc.) without hardcoding namespace names.

**Deployment:**

- Managed by ArgoCD application: `argocd/infra-apps/loki-rules.yaml`
- Auto-syncs from Git
- Namespace: `monitoring`

### Grafana (`grafana/`)

Contains Grafana dashboards and datasources managed via GitOps.

**How It Works:**

The kube-prometheus-stack Grafana includes a sidecar container that automatically loads:

- ConfigMaps with label `grafana_dashboard: "1"` as dashboards
- ConfigMaps with label `grafana_datasource: "1"` as datasources

**Current Configurations:**

- `loki-datasource.yaml` - Loki datasource pointing to `loki-gateway.monitoring.svc.cluster.local`
- `gramnuri-api-dashboard.yaml` - Application monitoring dashboard with:
  - HTTP request rate by status code
  - HTTP 5xx error tracking
  - Error logs panel (JSON parsed)
  - Request latency (p95)
  - Active connections

**Deployment:**

- Managed by ArgoCD application: `argocd/infra-apps/grafana-config.yaml`
- Auto-syncs from Git
- Namespace: `monitoring`
- See `monitoring/grafana/README.md` for detailed documentation

## Why Kustomize Instead of Helm?

These resources are managed with Kustomize (not Helm) because:

1. **Independent Lifecycle** - AlertmanagerConfig and Loki rules should be updated without touching Helm releases
2. **Separation of Concerns** - Helm manages the stack, Kustomize manages the configuration
3. **Easier Updates** - Change alert rules without upgrading entire monitoring stack
4. **GitOps-Friendly** - Direct mapping between Git files and Kubernetes resources
5. **No Templating Needed** - These are static configurations that don't need Helm templating

## Adding New Alert Rules

### For Metrics-Based Alerts (Prometheus)

Add to `argocd/values/kube-prometheus-stack.yaml`:

```yaml
additionalPrometheusRulesMap:
  custom-rules:
    groups:
      - name: my-rules
        rules:
          - alert: MyAlert
            expr: my_metric > 100
```

### For Log-Based Alerts (Loki)

Add to `monitoring/loki/loki-rules.yaml`:

```yaml
- alert: MyLogAlert
  expr: |
    sum(rate({app="my-app"} |~ "ERROR:" [1m])) > 0
  labels:
    severity: warning
```

Then add the alert name to `monitoring/alertmanager/discord-config.yaml`:

```yaml
matchers:
  - name: alertname
    value: Http5xxError|GoAPIErrorLogged|MyLogAlert
    matchType: "=~"
```

## Secrets

Alert receivers (Discord, Slack, etc.) require webhook URLs stored as Kubernetes secrets.

**Creating Secrets:**
Secrets are managed via Terraform in `infrastructure/terraform/secrets.tf`:

```hcl
resource "kubernetes_secret" "dev_alarms_webhook_url" {
  metadata {
    name      = "dev-alarms-webhook-url"
    namespace = "monitoring"
  }

  data = {
    webhook_url = var.dev_alarms_discord_webhook_url
  }
}
```

**Never commit webhook URLs to Git!**

## Testing

### Test AlertmanagerConfig

```bash
# Check if AlertmanagerConfig is created
kubectl get alertmanagerconfig -n monitoring

# Verify it's loaded in AlertManager
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- \
  cat /etc/alertmanager/config_out/alertmanager.env.yaml | grep discord
```

### Test Loki Rules

```bash
# Check if ConfigMap is created
kubectl get configmap -n monitoring loki-rules

# Check Loki Ruler logs
kubectl logs -n monitoring -l app.kubernetes.io/component=ruler --tail=50
```

### Send Test Alert

```bash
# Port-forward to AlertManager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Send test alert
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[{
  "labels": {
    "alertname": "Http5xxError",
    "severity": "critical",
    "namespace": "dev"
  },
  "annotations": {
    "summary": "Test alert"
  }
}]'
```

## Troubleshooting

### Alerts not routing to Discord

1. Check AlertmanagerConfig is applied:

   ```bash
   kubectl get alertmanagerconfig -n monitoring discord-webhook-config
   ```

2. Check AlertManager configuration:

   ```bash
   kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- \
     cat /etc/alertmanager/config_out/alertmanager.env.yaml
   ```

3. Check secret exists:

   ```bash
   kubectl get secret -n monitoring dev-alarms-webhook-url
   ```

4. Check AlertManager logs:
   ```bash
   kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0
   ```

### Loki rules not firing

1. Check Loki Ruler is running:

   ```bash
   kubectl get pods -n monitoring | grep loki-ruler
   ```

2. Check ruler configuration:

   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/component=ruler
   ```

3. Test LogQL query in Grafana:
   - Go to Explore
   - Select Loki datasource
   - Run: `sum(rate({app="gramnuri-api"} |~ "ERROR:" [1m]))`

## Related Documentation

- Main conventions: `/.cursorrules`
- Infrastructure setup: `/infrastructure/README.md`
- ArgoCD applications: `/argocd/README.md`
