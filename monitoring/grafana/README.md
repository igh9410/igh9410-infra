# Grafana Configuration (GitOps)

This directory contains Grafana dashboards and datasources managed via GitOps using the Grafana sidecar feature in kube-prometheus-stack.

## How It Works

The kube-prometheus-stack Grafana deployment includes a **sidecar container** that watches for ConfigMaps with specific labels:

- **Dashboards**: ConfigMaps with label `grafana_dashboard: "1"`
- **Datasources**: ConfigMaps with label `grafana_datasource: "1"`

When these ConfigMaps are created/updated, the sidecar automatically loads them into Grafana.

## Directory Structure

```
monitoring/grafana/
├── dashboards/              # Grafana dashboard definitions
│   └── gramnuri-api-dashboard.yaml
├── datasources/             # Grafana datasource configurations
│   └── loki-datasource.yaml
├── kustomization.yaml       # Kustomize manifest
└── README.md               # This file
```

## Creating New Dashboards

### Option 1: Export from Grafana UI (Recommended)

1. Create/edit dashboard in Grafana UI
2. Click **Share** → **Export** → **Save to file**
3. Create a ConfigMap wrapper:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |-
    {
      "dashboard": {
        # Paste exported JSON here
      }
    }
```

4. Add to `kustomization.yaml`
5. Commit and push

### Option 2: Write Dashboard JSON Manually

Use Grafana's [Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/json-model/) documentation.

## Creating New Datasources

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  my-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: MyDataSource
        type: prometheus  # or loki, tempo, etc.
        access: proxy
        url: http://my-service.monitoring.svc.cluster.local
        isDefault: false
        editable: true
```

## Important Notes

### Dashboard Versioning

- Dashboards are **not versioned** in Grafana when managed by sidecar
- The `version` field in dashboard JSON is ignored
- To track changes, rely on Git history

### Dashboard UID

- Set a unique `uid` in dashboard JSON to prevent duplicates
- If `uid` is not set, Grafana generates one automatically

```json
{
  "dashboard": {
    "uid": "gramnuri-api-monitoring",
    "title": "Gramnuri API Monitoring",
    ...
  }
}
```

### Namespace

- All ConfigMaps must be in the `monitoring` namespace
- The sidecar is configured with `searchNamespace: ALL`, but it's best practice to keep them in `monitoring`

### Sidecar Configuration

Current sidecar settings in `argocd/values/kube-prometheus-stack.yaml`:

```yaml
grafana:
  sidecar:
    dashboards:
      enabled: true
      searchNamespace: ALL
    datasources:
      enabled: true
      searchNamespace: ALL
```

## Deployment

Managed by ArgoCD application: `argocd/infra-apps/grafana-config.yaml`

```bash
# Sync manually
kubectl apply -k monitoring/grafana/

# Or wait for ArgoCD auto-sync
argocd app sync grafana-config
```

## Troubleshooting

### Dashboard not appearing

1. Check ConfigMap exists:

   ```bash
   kubectl get configmap -n monitoring -l grafana_dashboard=1
   ```

2. Check sidecar logs:

   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard
   ```

3. Verify label is correct:
   ```bash
   kubectl get configmap my-dashboard -n monitoring -o yaml | grep grafana_dashboard
   ```

### Datasource not loading

1. Check ConfigMap exists:

   ```bash
   kubectl get configmap -n monitoring -l grafana_datasource=1
   ```

2. Check sidecar logs:

   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-datasources
   ```

3. Verify YAML syntax:
   ```bash
   kubectl get configmap my-datasource -n monitoring -o jsonpath='{.data}'
   ```

### Force reload

Restart Grafana pod to force reload all dashboards/datasources:

```bash
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
```

## Best Practices

1. **Use descriptive names** - Name ConfigMaps clearly: `{app}-{type}-dashboard`
2. **One dashboard per ConfigMap** - Don't bundle multiple dashboards in one ConfigMap
3. **Set UIDs explicitly** - Prevents duplicate dashboards on updates
4. **Test in Grafana UI first** - Create/test in UI, then export to Git
5. **Use variables** - Make dashboards reusable with template variables
6. **Add documentation** - Include description and tags in dashboard JSON
7. **Version control** - Commit meaningful changes with clear commit messages

## Example: Multi-Environment Dashboard

Use Grafana variables to make dashboards work across environments:

```json
{
  "dashboard": {
    "templating": {
      "list": [
        {
          "name": "namespace",
          "type": "query",
          "query": "label_values(up{app=\"gramnuri-api\"}, namespace)",
          "multi": false,
          "includeAll": false
        }
      ]
    },
    "panels": [
      {
        "targets": [
          {
            "expr": "rate(http_requests_total{app=\"gramnuri-api\", namespace=\"$namespace\"}[5m])"
          }
        ]
      }
    ]
  }
}
```

## Resources

- [Grafana Sidecar Documentation](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards)
- [Grafana Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/json-model/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [kube-prometheus-stack Values](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml)
