# 🏠 Homelab Infra

This repository contains all of the configuration and documentation of my homelab.
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

## :rocket: Installed Apps & Tools

### Apps

This is where my custom apps reside.

| Name             | Description                |
| ---------------- | -------------------------- |
| `artskorner-api` | API for the Artskorner app |
| `gramnuri-api`   | API for the Gramnuri app   |

### Infrastructure

Everything needed to run my cluster & deploy my applications.

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cncf/artwork/master/projects/k3s/icon/color/k3s-icon-color.svg"></td>
        <td><a href="https://k3s.io/">k3s</a></td>
        <td>Lightweight Kubernetes distribution.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cncf/artwork/main/projects/argo/icon/color/argo-icon-color.svg"></td>
        <td><a href="https://argo-cd.readthedocs.io/">ArgoCD</a></td>
        <td>My GitOps solution of choice.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cncf/artwork/main/projects/cilium/icon/color/cilium-icon-color.svg"></td>
        <td><a href="https://cilium.io/">Cilium</a></td>
        <td>My CNI of choice. Used for CNI, LoadBalancer, and Ingress Controller. eBPF-based Networking, Observability, Security.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cloudflare/cloudflare-docs/production/products/tunnel/static/cloudflare-tunnel-icon.svg"></td>
        <td><a href="https://www.cloudflare.com/products/tunnel/">Cloudflared Tunnel</a></td>
        <td>Used for private tunnels to expose public services (without requiring a public IP).</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/docs/src/assets/logo.png"></td>
        <td><a href="https://cloudnative-pg.io/">CloudNativePG</a></td>
        <td>Database operator for running PostgreSQL clusters.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/cncf/artwork/main/projects/prometheus/icon/color/prometheus-icon-color.svg"></td>
        <td><a href="https://prometheus.io/">Prometheus</a></td>
        <td>An open-source monitoring system with a dimensional data model, flexible query language, efficient time series database and modern alerting approach.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/grafana/grafana/main/public/img/grafana_icon.svg"></td>
        <td><a href="https://grafana.com/">Grafana</a></td>
        <td>The open observability platform.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/grafana/loki/main/docs/sources/logo.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log aggregation system.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/grafana/alloy/main/docs/sources/assets/logo_and_name.svg"></td>
        <td><a href="https://grafana.com/oss/alloy/">Alloy</a></td>
        <td>Open-source observability pipelines.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/hashicorp/terraform-website/main/content/assets/images/terraform-logo-150x150.png"></td>
        <td><a href="https://www.terraform.io/">Terraform</a></td>
        <td>Infrastructure as Code to provision and manage any cloud, infrastructure, or service.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/logo/kustomize-color.png"></td>
        <td><a href="https://kustomize.io/">Kustomize</a></td>
        <td>Kubernetes native configuration management.</td>
    </tr>
</table>

## Networking

I use [Cilium](https://cilium.io/) as my CNI. I use its LoadBalancer IPAM to assign IP addresses to my LoadBalancer services and also use Cilium as an Ingress controller. This way, I don't need to install and maintain a seperate ingress controller.

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

## 📈 Future Improvements

- [ ] Implement comprehensive CI/CD pipeline testing
- [ ] Add automated security scanning
- [ ] Implement disaster recovery procedures
- [ ] Add performance testing automation
- [ ] Implement multi-cluster deployment
- [ ] Add cost optimization monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following the established patterns
4. Test changes in development environment
5. Submit pull request with detailed description
