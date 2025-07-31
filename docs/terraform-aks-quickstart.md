# Terraform AKS Quick Start Guide

## Overview

Since Crossplane Azure provider has API version compatibility issues, this guide shows how to use Terraform to provision AKS clusters in the pltsrv-kube-platform solution.

## Current Working Setup

The project already has a working Terraform configuration for AKS clusters in `terraform/main.tf`.

## Quick Start: Create a New AKS Cluster

### Step 1: Navigate to Terraform Directory

```bash
cd terraform
```

### Step 2: Review Current Configuration

The current AKS module configuration:

```hcl
module "aks" {
  source = "Azure/aks/azurerm"
  version = "10.2.0"
  
  resource_group_name = azurerm_resource_group.this.name
  location           = var.location
  cluster_name       = var.cluster_name
  
  default_node_pool = {
    name                = "default"
    max_count           = var.max_count
    min_count           = var.min_count
    node_count          = var.node_count
    vm_size             = var.vm_size
    enable_auto_scaling = var.enable_auto_scaling
    max_pods            = var.max_pods
    os_disk_size_gb     = var.os_disk_size_gb
    os_sku              = var.os_sku
    type                = "VirtualMachineScaleSets"
  }
  
  network_plugin = var.network_plugin
  os_disk_size_gb = var.os_disk_size_gb
  os_sku          = var.os_sku
  prefix          = var.prefix
  
  # ... other configurations
}
```

### Step 3: Create a New AKS Cluster

#### Option A: Use Existing Configuration (Recommended)

The current setup already creates an AKS cluster. To create additional clusters, you can:

1. **Modify the existing configuration** to create multiple clusters
2. **Use Terraform workspaces** to manage multiple environments
3. **Create separate Terraform configurations** for different clusters

#### Option B: Create a New Terraform Configuration

Create a new file `terraform/aks-clusters.tf`:

```hcl
# terraform/aks-clusters.tf
module "aks_dev" {
  source = "Azure/aks/azurerm"
  version = "10.2.0"
  
  resource_group_name = azurerm_resource_group.this.name
  location           = "WestUS3"
  cluster_name       = "aks-dev-cluster"
  
  default_node_pool = {
    name                = "default"
    max_count           = 5
    min_count           = 1
    node_count          = 2
    vm_size             = "Standard_D2s_v3"
    enable_auto_scaling = true
    max_pods            = 50
    os_disk_size_gb     = 128
    os_sku              = "AzureLinux"
    type                = "VirtualMachineScaleSets"
  }
  
  network_plugin = "azure"
  os_disk_size_gb = 128
  os_sku          = "AzureLinux"
  prefix          = "dev"
  
  tags = {
    Environment = "dev"
    Project     = "pltsrv-kube-platform"
  }
}

module "aks_staging" {
  source = "Azure/aks/azurerm"
  version = "10.2.0"
  
  resource_group_name = azurerm_resource_group.this.name
  location           = "WestUS3"
  cluster_name       = "aks-staging-cluster"
  
  default_node_pool = {
    name                = "default"
    max_count           = 10
    min_count           = 2
    node_count          = 3
    vm_size             = "Standard_D4s_v3"
    enable_auto_scaling = true
    max_pods            = 50
    os_disk_size_gb     = 128
    os_sku              = "AzureLinux"
    type                = "VirtualMachineScaleSets"
  }
  
  network_plugin = "azure"
  os_disk_size_gb = 128
  os_sku          = "AzureLinux"
  prefix          = "staging"
  
  tags = {
    Environment = "staging"
    Project     = "pltsrv-kube-platform"
  }
}
```

### Step 4: Plan and Apply

```bash
# Initialize Terraform (if not already done)
terraform init

# Plan the changes
terraform plan

# Apply the changes
terraform apply
```

### Step 5: Get Cluster Credentials

```bash
# Get credentials for the new cluster
az aks get-credentials --resource-group rg-aks-mgt-poc --name aks-dev-cluster

# Verify access
kubectl cluster-info
kubectl get nodes
```

## Using Terraform Variables

### Create a Variables File

Create `terraform/terraform.tfvars`:

```hcl
# terraform/terraform.tfvars
location = "WestUS3"
cluster_name = "aks-dev-cluster"
node_count = 2
vm_size = "Standard_D2s_v3"
max_count = 5
min_count = 1
enable_auto_scaling = true
max_pods = 50
os_disk_size_gb = 128
os_sku = "AzureLinux"
network_plugin = "azure"
prefix = "dev"
```

### Apply with Variables

```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Managing Multiple Environments

### Using Terraform Workspaces

```bash
# Create a workspace for dev environment
terraform workspace new dev

# Create a workspace for staging environment
terraform workspace new staging

# Switch between workspaces
terraform workspace select dev
terraform plan
terraform apply

terraform workspace select staging
terraform plan
terraform apply
```

### Using Separate State Files

Create separate directories for each environment:

```bash
mkdir -p terraform/environments/dev
mkdir -p terraform/environments/staging
mkdir -p terraform/environments/prod

# Copy configuration files to each environment
cp terraform/main.tf terraform/environments/dev/
cp terraform/variables.tf terraform/environments/dev/
cp terraform/provider.tf terraform/environments/dev/

# Repeat for staging and prod
```

## Monitoring and Management

### Check Cluster Status

```bash
# List AKS clusters
az aks list --resource-group rg-aks-mgt-poc

# Get cluster details
az aks show --resource-group rg-aks-mgt-poc --name aks-dev-cluster

# Get cluster credentials
az aks get-credentials --resource-group rg-aks-mgt-poc --name aks-dev-cluster
```

### Scale Cluster

```bash
# Scale node count
az aks scale --resource-group rg-aks-mgt-poc --name aks-dev-cluster --node-count 5

# Or use Terraform
terraform apply -var="node_count=5"
```

### Update Cluster

```bash
# Update Kubernetes version
az aks upgrade --resource-group rg-aks-mgt-poc --name aks-dev-cluster --kubernetes-version 1.28.0

# Or use Terraform
terraform apply -var="kubernetes_version=1.28.0"
```

## Cleanup

### Delete Cluster

```bash
# Delete using Terraform
terraform destroy -target=module.aks_dev

# Or delete using Azure CLI
az aks delete --resource-group rg-aks-mgt-poc --name aks-dev-cluster --yes
```

### Cleanup Resources

```bash
# Delete resource group (will delete all resources)
az group delete --name rg-aks-mgt-poc --yes --no-wait
```

## Best Practices

### 1. **Use Variables**
- Define all configurable values as variables
- Use `.tfvars` files for different environments

### 2. **State Management**
- Use remote state storage (Azure Storage Account)
- Use workspaces for environment separation

### 3. **Security**
- Use managed identities
- Enable RBAC
- Use private clusters when possible

### 4. **Monitoring**
- Enable Azure Monitor
- Set up logging and metrics
- Configure alerts

### 5. **Backup**
- Regular backups of Terraform state
- Version control for configurations
- Document all changes

## Integration with GitOps

### ArgoCD Integration

The current setup already includes ArgoCD. You can:

1. **Store Terraform outputs** as Kubernetes secrets
2. **Use ArgoCD** to deploy applications to the new clusters
3. **Configure ArgoCD** to manage multiple clusters

### Example: Store Cluster Credentials

```hcl
# terraform/outputs.tf
output "aks_dev_kubeconfig" {
  value = module.aks_dev.kubeconfig
  sensitive = true
}

# Store in Kubernetes secret
resource "kubernetes_secret" "aks_dev_credentials" {
  metadata {
    name = "aks-dev-credentials"
    namespace = "argocd"
  }
  
  data = {
    kubeconfig = module.aks_dev.kubeconfig
  }
}
```

## Troubleshooting

### Common Issues

1. **Resource Group Not Found**:
   ```bash
   az group create --name rg-aks-mgt-poc --location WestUS3
   ```

2. **Permission Issues**:
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

3. **Network Issues**:
   - Check VNet configuration
   - Verify subnet settings
   - Check NSG rules

### Debug Commands

```bash
# Check Terraform state
terraform state list
terraform state show module.aks_dev

# Check Azure resources
az resource list --resource-group rg-aks-mgt-poc

# Check cluster status
az aks show --resource-group rg-aks-mgt-poc --name aks-dev-cluster
```

## Next Steps

1. **Set up monitoring** with Dynatrace
2. **Configure GitOps** workflows
3. **Implement CI/CD** pipelines
4. **Set up backup and disaster recovery**
5. **Configure security policies**

## References

- [Terraform AKS Module](https://registry.terraform.io/modules/Azure/aks/azurerm/latest)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html) 