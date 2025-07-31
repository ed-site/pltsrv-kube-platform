# Crossplane AKS Cluster Provisioning Guide

## Overview

This guide explains how to provision Azure Kubernetes Service (AKS) clusters using Crossplane in the pltsrv-kube-platform solution.

## Current Status

### ❌ **Crossplane Azure Provider Issue**

The Crossplane Azure provider has a critical limitation with API versions:

**v1.4.0 Issues:**
- **API Version**: Uses `2023-06-02-preview` which is **not supported** in any Azure region
- **Error**: `NoRegisteredProviderFound: No registered resource provider found for location 'centralus' and API version '2023-06-02-preview'`

**v1.13.1 Issues (Updated but still problematic):**
- **API Version**: Uses `2023-09-02-preview` which is **still not supported** in any Azure region
- **Error**: `InvalidApiVersionParameter: The api-version '2023-09-02-preview' is invalid`
- **Impact**: AKS cluster provisioning still fails with API version compatibility errors

The provider continues to use preview API versions that are not available in production Azure regions.

**Testing Results (January 31, 2025):**
- ✅ Provider update from v1.4.0 to v1.13.1 was successful
- ✅ Cluster claim creation works with proper kustomize structure
- ✅ Resource Group, VirtualNetwork, and Subnet provisioning successful
- ❌ Kubernetes Cluster provisioning still fails due to unsupported API version
- 📋 Supported API versions include: `2025-04-01`, `2025-03-01`, `2024-11-01`, `2024-08-01`, etc.
- ❌ Provider still uses preview versions: `2023-09-02-preview` (not supported)

### ✅ **Working Alternatives**

1. **Terraform** (Recommended for immediate use)
2. **Azure CLI** (Direct provisioning)
3. **Wait for Crossplane provider update** (Future solution)

## Solution 1: Terraform AKS Provisioning (Immediate)

### Current Terraform Setup

The project already has a working Terraform configuration for AKS:

```hcl
# terraform/main.tf
module "aks" {
  source = "Azure/aks/azurerm"
  version = "10.2.0"
  
  resource_group_name = azurerm_resource_group.this.name
  location           = var.location
  cluster_name       = var.cluster_name
  
  # Node pool configuration
  default_node_pool = {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
  }
  
  # Network configuration
  network_plugin = var.network_plugin
  # ... other configurations
}
```

### How to Use Terraform for AKS

1. **Create a new AKS cluster**:
   ```bash
   cd terraform
   terraform plan -var="cluster_name=my-new-aks-cluster"
   terraform apply -var="cluster_name=my-new-aks-cluster"
   ```

2. **Modify existing configuration**:
   ```bash
   # Edit terraform/variables.tf to add new variables
   # Edit terraform/main.tf to add new AKS module
   terraform plan
   terraform apply
   ```

## Solution 2: Crossplane AKS Provisioning (When Fixed)

### Prerequisites

1. **Crossplane Core**: Already installed in the solution
2. **Azure Provider**: Already installed (but has API version issues)
3. **Composite Resource Definitions**: Already defined

### Step 1: Verify Crossplane Setup

```bash
# Check Crossplane installation
kubectl get pods -n crossplane-system

# Check Azure provider
kubectl get provider.pkg.crossplane.io -A

# Check Composite Resource Definitions
kubectl get xrd -A
```

### Step 2: Create AKS Cluster Claim

When the provider is fixed, create a cluster claim:

```yaml
# gitops/clusters/crossplane/clusters/shared/my-aks-cluster/cluster-claim.yaml
apiVersion: kubernetes.mckesson.com/v1alpha1
kind: AksClusterClaim
metadata:
  name: my-aks-cluster
  annotations:
    crossplane.io/external-name: my-aks-cluster
spec:
  writeConnectionSecretToRef:
    name: my-aks-cluster-secret
  location: "WestUS3"  # Use supported region
  aks:
    defaultNodePool:
      name: "default"
      maxCount: 5
      minCount: 1
      nodeCount: 2
      vmSize: "Standard_D2s_v3"
      enableAutoScaling: true
      maxPods: 50
      osDiskSizeGb: 128
      osSku: "AzureLinux"
      type: "VirtualMachineScaleSets"
    networkProfile:
      - dnsServiceIp: "10.0.0.10"
        serviceCidr: "10.0.0.0/16"
        podCidr: "10.1.0.0/16"
        networkPlugin: "azure"
        networkPolicy: "azure"
        outboundType: "loadBalancer"
    tags:
      environment: dev
      "core-snow-as-number": "123456789"
  userNodePool:
    name: "userpool"
    mode: "user"
    maxCount: 10
    minCount: 1
    nodeCount: 2
    vmSize: "Standard_D4s_v3"
    enableAutoScaling: true
    maxPods: 50
    osDiskSizeGb: 128
    osSku: "AzureLinux"
    osType: "Linux"
  virtualNetwork:
    addressSpace: ["10.100.0.0/16"]
    tags:
      environment: dev
  subnet:
    name: "aks-subnet"
    addressPrefixes: ["10.100.0.0/24"]
    privateEndpointNetworkPoliciesEnabled: true
    privateLinkServiceNetworkPoliciesEnabled: true
```

### Step 3: Apply the Cluster Claim

```bash
# Apply using kustomize
kubectl apply -k gitops/clusters/crossplane/clusters/shared/my-aks-cluster/

# Or apply directly
kubectl apply -f gitops/clusters/crossplane/clusters/shared/my-aks-cluster/cluster-claim.yaml
```

### Step 4: Monitor Provisioning

```bash
# Check cluster claim status
kubectl get aksclusterclaim my-aks-cluster

# Check composite resource
kubectl get xakscluster

# Check managed resources
kubectl get resourcegroup,kubernetescluster,subnet,virtualnetwork -l crossplane.io/composite

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Solution 3: Azure CLI Direct Provisioning

### Quick AKS Cluster Creation

```bash
# Create resource group
az group create --name rg-my-aks-cluster --location WestUS3

# Create AKS cluster
az aks create \
  --resource-group rg-my-aks-cluster \
  --name my-aks-cluster \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --network-plugin azure \
  --network-policy azure \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group rg-my-aks-cluster --name my-aks-cluster
```

## Monitoring and Troubleshooting

### Check Crossplane Provider Status

```bash
# Check provider logs
kubectl logs -n crossplane-system -l app=crossplane-provider-azure

# Check provider configuration
kubectl get providerconfig.azure.upbound.io default -o yaml
```

### Common Issues and Solutions

1. **API Version Errors**:
   - **Issue**: `NoRegisteredProviderFound` for API version `2023-06-02-preview`
   - **Solution**: Wait for provider update or use Terraform/Azure CLI

2. **Resource Group Deletion Issues**:
   - **Issue**: Resource group contains resources that can't be deleted
   - **Solution**: Manually delete nested resources first, then resource group

3. **Missing Required Fields**:
   - **Issue**: `spec.virtualNetwork.addressSpace: Required value`
   - **Solution**: Ensure all required fields are specified in cluster claim

### Cleanup Commands

```bash
# Delete cluster claim
kubectl delete aksclusterclaim my-aks-cluster -n my-aks-cluster

# Delete managed resources
kubectl delete resourcegroup,kubernetescluster,subnet,virtualnetwork -l crossplane.io/composite

# Force delete if stuck
kubectl patch resourcegroup <resource-name> --type='merge' -p='{"metadata":{"finalizers":[]}}'

# Delete namespace
kubectl delete namespace my-aks-cluster
```

## Best Practices

### 1. **Use Supported Regions**
- Avoid regions that don't support the required API versions
- Test in multiple regions to find compatibility

### 2. **Resource Naming**
- Use consistent naming conventions
- Include environment and purpose in names

### 3. **Monitoring**
- Set up proper monitoring and alerting
- Use Azure Monitor and Dynatrace (already configured)

### 4. **Security**
- Use managed identities where possible
- Implement proper RBAC
- Enable Azure Security Center

### 5. **Backup and Recovery**
- Regular backups of cluster configurations
- Document recovery procedures

## Future Improvements

### 1. **Provider Updates**
- Monitor Crossplane Azure provider releases
- Update when new versions with supported API versions are available

### 2. **Enhanced Monitoring**
- Integrate with existing Dynatrace setup
- Add custom metrics and dashboards

### 3. **Automation**
- Implement automated cluster provisioning workflows
- Add validation and testing pipelines

### 4. **Multi-Region Support**
- Deploy clusters across multiple regions
- Implement disaster recovery strategies

## References

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Terraform AKS Module](https://registry.terraform.io/modules/Azure/aks/azurerm/latest)
- [Crossplane Azure Provider](https://marketplace.upbound.io/providers/crossplane-contrib/provider-azure)

## Support

For issues with:
- **Crossplane**: Check provider logs and GitHub issues
- **Azure**: Use Azure support or documentation
- **Terraform**: Check Terraform documentation and community forums 