---
page_type: sample
languages:
- bash
- terraform
- yaml
- json
products:
- azure
- azure-resource-manager
- azure-kubernetes-service
- azure-container-registry
- azure-storage
- azure-blob-storage
- azure-storage-accounts
- azure-monitor
- azure-log-analytics
- azure-virtual-machines
name:  Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)
description: This project demonstrates the process of implementing a consistent and solid platform engineering strategy on the Azure platform using Azure Kubernetes Service (AKS), ArgoCD, and Crossplane.
urlFragment: pltsrv-kube-platform
---

# AKS Container Platform with GitOps

A comprehensive Azure Kubernetes Service (AKS) based container platform that implements GitOps practices using ArgoCD, Crossplane for infrastructure management, and Backstage for developer portal.

## 🚀 Features

- **AKS Cluster Management**: Automated provisioning with Terraform
- **GitOps Workflow**: ArgoCD for continuous deployment
- **Infrastructure as Code**: Crossplane for cloud resource management
- **Developer Portal**: Backstage for service catalog and developer experience
- **TLS Security**: Automated certificate generation and management
- **Multi-Environment Support**: Dev, staging, and production environments
- **Monitoring & Observability**: Integrated with Azure Monitor and Dynatrace

## 📋 Prerequisites

- Azure CLI with appropriate permissions
- Terraform >= 1.1.0
- kubectl
- Helm >= 3.0
- OpenSSL (for certificate generation)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Azure Cloud   │    │   GitOps Repo   │    │   Backstage     │
│                 │    │                 │    │   Portal        │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │    AKS      │ │    │ │   ArgoCD    │ │    │ │  Developer  │ │
│ │  Cluster    │ │    │ │ Applications│ │    │ │  Portal     │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │  Crossplane │ │    │ │  GitOps     │ │    │ │  Service    │ │
│ │  Providers  │ │    │ │  Workflows  │ │    │ │  Catalog    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/ed-site/pltsrv-kube-platform.git
cd pltsrv-kube-platform
```

### 2. Generate TLS Certificates

```bash
# Generate certificates for development
./dev/generate-cert.sh
```

### 3. Configure Azure

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription <your-subscription-id>
```

### 4. Deploy Infrastructure

```bash
# Navigate to Terraform directory
cd terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

### 5. Access the Platform

After deployment, you can access:

- **Backstage Portal**: `https://<aks-public-ip>`
- **ArgoCD**: `https://<aks-public-ip>:8080`
- **Kubernetes Dashboard**: Via kubectl proxy

## 📁 Project Structure

```
pltsrv-kube-platform/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   └── provider.tf           # Provider configuration
├── gitops/                   # GitOps configurations
│   ├── apps/                 # Application manifests
│   ├── clusters/             # Cluster configurations
│   ├── environments/         # Environment-specific configs
│   └── bootstrap/            # ArgoCD bootstrap
├── backstage/                # Backstage application
│   ├── packages/             # Backstage packages
│   ├── backstagechart/       # Helm chart for Backstage
│   └── Dockerfile            # Container image
├── dev/                      # Development tools
│   ├── docs/                 # Documentation
│   ├── certs/                # Generated certificates
│   └── generate-cert.sh      # Certificate generation script
└── docs/                     # Project documentation
```

## 🔧 Configuration

### Environment Variables

Create a `terraform.tfvars` file with your configuration:

```hcl
# Azure Configuration
location = "westus3"
cluster_name = "aks-mgt-poc"

# Network Configuration
network_plugin = "azure"
network_policy = "azure"

# Node Pool Configuration
agents_size = "Standard_D2s_v3"
agents_min_count = 1
agents_max_count = 5

# Backstage Configuration
build_backstage = true
postgres_password = "your-secure-password"
```

### TLS Certificate Configuration

The platform uses TLS certificates for secure communication. Certificates are automatically generated and configured for:

- Backstage portal
- ArgoCD interface
- Ingress controllers

## 🔒 Security

- **Workload Identity**: Azure AD integration for secure authentication
- **TLS Encryption**: End-to-end encryption for all communications
- **RBAC**: Role-based access control for Kubernetes resources
- **Network Policies**: Azure CNI with network policies enabled
- **Private Clusters**: Option to deploy as private AKS clusters

## 📊 Monitoring & Observability

The platform integrates with:

- **Azure Monitor**: Built-in monitoring and logging
- **Dynatrace**: Advanced observability (optional)
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards

## 🔄 GitOps Workflow

1. **Infrastructure Changes**: Modify Terraform configurations
2. **Application Changes**: Update Kubernetes manifests in `gitops/` directory
3. **ArgoCD Sync**: Automatic deployment via ArgoCD
4. **Crossplane Management**: Infrastructure resources managed by Crossplane

## 🛠️ Development

### Adding New Applications

1. Create application manifests in `gitops/apps/`
2. Configure ArgoCD Application resources
3. Commit and push to trigger deployment

### Customizing Backstage

1. Modify Backstage configuration in `backstage/app-config.yaml`
2. Add custom plugins in `backstage/packages/`
3. Update Helm chart values in `backstage/backstagechart/values.yaml`

### Extending Infrastructure

1. Add new Crossplane compositions in `gitops/clusters/crossplane/`
2. Update Terraform modules as needed
3. Configure new Azure resources via Crossplane providers

## 🧪 Testing

```bash
# Run Terraform validation
cd terraform
terraform validate

# Test certificate generation
./dev/generate-cert.sh

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f gitops/
```

## 📚 Documentation

- [Terraform Configuration Guide](docs/terraform.md)
- [GitOps Workflow](docs/gitops.md)
- [Backstage Customization](docs/backstage.md)
- [TLS Certificate Management](dev/docs/openssl-tls-certificate-generation.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/ed-site/pltsrv-kube-platform/issues)
- **Documentation**: [Project Wiki](https://github.com/ed-site/pltsrv-kube-platform/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/ed-site/pltsrv-kube-platform/discussions)

## 🙏 Acknowledgments

- [Azure Kubernetes Service](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)
- [Crossplane](https://crossplane.io/)
- [Backstage](https://backstage.io/)
- [Terraform](https://www.terraform.io/)

---

**Note**: This platform is designed for production use but should be thoroughly tested in your environment before deployment.
