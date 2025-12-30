# Generic App Helm Chart

A reusable Helm chart for deploying web applications in the igh9410 infrastructure.

## Usage

This chart is designed to replace repetitive Kustomize configurations for similar applications. It supports:

- Environment-specific configurations (dev/prod)
- App-specific settings (ports, resources, monitoring)
- Gateway API HTTPRoutes
- ServiceMonitor for Prometheus metrics

## Values Files

The chart uses separate values files for each application and environment combination:

- `values/gramnuri-api-dev.yaml` - gramnuri-api in development
- `values/gramnuri-api-prod.yaml` - gramnuri-api in production
- `values/gramnuri-web-dev.yaml` - gramnuri-web in development
- `values/gramnuri-web-prod.yaml` - gramnuri-web in production

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicas` | Number of replicas | `1` |
| `image.repository` | Container image repository | `""` |
| `image.tag` | Container image tag | `"latest"` |
| `containerPort` | Port the container listens on | `8080` |
| `service.port` | Service port | `80` |
| `service.portName` | Service port name | `"http"` |
| `httproute.hostnames` | List of hostnames for HTTPRoute | `[]` |
| `resources` | Resource limits and requests | `{}` |
| `envFrom` | Environment variables from secrets/configmaps | `[]` |
| `serviceMonitor.enabled` | Enable ServiceMonitor | `false` |

## Adding New Applications

1. Create a new values file in `values/` directory following the naming pattern `{app}-{env}.yaml`
2. Update the corresponding ArgoCD application to reference the new values file
3. Customize the values as needed for your application

## Migration from Kustomize

This chart replaces the previous Kustomize-based deployments in:
- `apps/gramnuri-api/overlays/`
- `apps/gramnuri-web/overlays/`

The old Kustomize configurations can be removed after verifying the Helm deployments work correctly.
