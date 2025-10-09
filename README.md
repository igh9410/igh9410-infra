# 🔬 igh9410-infra

All the infrastructure-as-code, configurations, and documentation for my homelab are stored in this repository.
I use my homelab for deploying my side projects and experiment new technologies and Kubernetes cluster.

## Cluster Provisioning & Architecture

I use a k3s cluster as my Kubernetes platform. And I use XCP-NG for provisioning virtual machines in my hardware.

Initial cluster provisioning of core infrastructure components like ArgoCD and Cloudflared is done using Terraform. The Terraform code for this is located in the `infrastructure/terraform` directory.

Once the core components are up and running, I follow GitOps principles using ArgoCD for managing all applications. ArgoCD is configured to watch this Git repository and automatically deploy and manage applications, including Helm charts and Kustomize configurations, as they are defined.

## 📁 Repository Structure

```
igh9410-infra/
├── apps/                           # Application definitions
│   ├── artskorner-api/
│   │   ├── base/                   # Base Kubernetes manifests
│   │   ├── overlays/prod/
│   │   └── terraform/prod/
│   └── gramnuri-api/
│       ├── base/                   # Base Kubernetes manifests
│       ├── overlays/dev/           # Development-specific patches
│       └── terraform/dev/          # App-specific infrastructure
├── argocd/                         # ArgoCD configuration
│   ├── apps/                       # Application definitions
│   ├── infra-apps/                 # Infrastructure application definitions
│   └── values/                     # Helm values for ArgoCD Applications
├── infrastructure/                 # Kubernetes manifests and Terraform code for infrastructure
│   └── cilium/                     # Cilium stack
│   └── terraform/                  # Main infrastructure code
├── diagram/                        # Architecture diagrams
└── Makefile                        # Automation scripts
```

## Core Components & Applications

### Custom Applications

- **artskorner-api**: API for the Artskorner app.
- **gramnuri-api**: API for the Gramnuri app.

### Core Components

#### <img src="https://raw.githubusercontent.com/cncf/artwork/master/projects/k3s/icon/color/k3s-icon-color.svg" width="20" valign="middle"> [k3s](https://k3s.io/)
Lightweight Kubernetes distribution.

#### <img src="https://raw.githubusercontent.com/cncf/artwork/main/projects/argo/icon/color/argo-icon-color.svg" width="20" valign="middle"> [ArgoCD](https://argo-cd.readthedocs.io/)
Declarative, GitOps continuous delivery tool for Kubernetes.

#### <img src="https://github.com/cncf/artwork/blob/main/projects/cilium/icon/color/cilium_icon-color.png?raw=true" width="20" valign="middle"> [Cilium](https://cilium.io/)
eBPF-based Networking, Observability, Security. Used for CNI, LoadBalancer, and Ingress Controller.

#### <img src="https://cdn.brandfetch.io/idJ3Cg8ymG/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1667589504295" width="20" valign="middle"> [Cloudflared Tunnel](https://www.cloudflare.com/products/tunnel/)
Used for private tunnels to expose public services without a publicly routable IP.

#### <img src="https://github.com/cncf/artwork/blob/main/projects/cloudnativepg/icon/color/cloudnativepg-icon-color.png?raw=true" width="20" valign="middle"> [CloudNativePG](https://cloudnative-pg.io/)
Postgres operator for Kubernetes-native environment.

#### <img src="https://raw.githubusercontent.com/cncf/artwork/main/projects/prometheus/icon/color/prometheus-icon-color.svg" width="20" valign="middle"> [Prometheus](https://prometheus.io/)
Open-source monitoring system with a dimensional data model, flexible query language, efficient time series database and modern alerting approach.

#### <img src="https://raw.githubusercontent.com/grafana/grafana/main/public/img/grafana_icon.svg" width="20" valign="middle"> [Grafana](https://grafana.com/)
The open observability dashboards.

#### <img src="https://raw.githubusercontent.com/grafana/loki/main/docs/sources/logo.png" width="20" valign="middle"> [Loki](https://grafana.com/oss/loki/)
Log aggregation system.

#### <img src="https://grafana.com/media/oss/alloy/alloy-logo.svg" width="20" valign="middle"> [Grafana Alloy](https://grafana.com/oss/alloy/)
Open-source OpenTelemetry collector.

## Networking

[Cilium](https://cilium.io/) is the cornerstone of my cluster's network architecture. It serves as the CNI and provides both LoadBalancer IPAM and Ingress functionality, allowing for a more streamlined setup without a dedicated ingress controller.

For external access, I use [Cloudflared Tunnel](https://www.cloudflare.com/products/tunnel/) to expose services to the internet securely without needing a public IP address.

## Database

For stateful workloads, I use [CloudNativePG](https://cloudnative-pg.io/) to manage PostgreSQL clusters on Kubernetes. It handles the entire lifecycle of a PostgreSQL cluster, from bootstrapping and configuration to high availability and disaster recovery.

## 🔄 GitOps Workflow

### Application Deployment Flow

1. **Code Changes**: Push application code to respective repositories
2. **Image Build**: GitHub Actions builds and pushes container images
3. **Manifest Update**: Update image tags in Kustomize overlays
4. **ArgoCD Sync**: ArgoCD detects changes and deploys automatically

### Infrastructure Updates

1. **Terraform Changes**: Modify infrastructure code
2. **Plan & Apply**: Review and apply Terraform changes
3. **ArgoCD Config**: Update ArgoCD applications if needed
4. **Verification**: Ensure services are healthy
