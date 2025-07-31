# Fixing Crossplane Azure Provider API Version Issue

## Problem

The Crossplane Azure provider (v1.13.1) uses unsupported preview API versions:
- **Current**: `2023-09-02-preview` (not supported in production regions)
- **Required**: Use supported versions like `2024-11-01`, `2025-04-01`, etc.

## Root Cause

The provider is hardcoded to use preview API versions that are not available in production Azure regions.

## Solutions

### Solution 1: Environment Variables (Recommended)

Update the Helm chart values to set environment variables:

```yaml
# gitops/environments/default/addons/crossplane-azure-upbound/values.yaml
deploymentRuntimeConfig:
  enabled: true
  env:
    - name: AZURE_API_VERSION
      value: "2024-11-01"
    - name: TF_VAR_azure_api_version
      value: "2024-11-01"
    - name: TF_VAR_azurerm_api_version
      value: "2024-11-01"
```

### Solution 2: Provider Configuration Override

Create a custom provider configuration:

```yaml
# gitops/environments/default/addons/crossplane-azure-upbound/provider-config.yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  # ... existing configuration ...
  apiVersion: "2024-11-01"  # Override API version
```

### Solution 3: Terraform Provider Configuration

Since Crossplane uses Terraform under the hood, configure the Azure provider:

```hcl
# terraform/provider.tf
provider "azurerm" {
  features {}
  # Force API version
  api_version = "2024-11-01"
}
```

### Solution 4: Update Provider Version

Wait for a newer provider version that uses supported API versions:

```bash
# Check for newer versions
kubectl get provider.pkg.crossplane.io -A

# Update when available
kubectl patch provider.pkg.crossplane.io provider-azure-containerservice \
  -p='{"spec":{"package":"xpkg.upbound.io/upbound/provider-azure-containerservice:v1.14.0"}}'
```

## Implementation Steps

### Step 1: Apply Environment Variables

```bash
# Update the Helm chart
helm upgrade crossplane-azure-upbound \
  gitops-bridge-dev/crossplane-azure-upbound \
  --values gitops/environments/default/addons/crossplane-azure-upbound/values.yaml \
  -n crossplane-system
```

### Step 2: Restart Provider Pods

```bash
# Restart the containerservice provider
kubectl rollout restart deployment provider-azure-containerservice -n crossplane-system

# Verify the environment variables
kubectl get pod -n crossplane-system -l app=crossplane-provider-azure -o yaml | grep -A 10 env
```

### Step 3: Test the Fix

```bash
# Create a test cluster claim
kubectl apply -k gitops/clusters/crossplane/clusters/shared/aks-test-cluster/

# Monitor the logs
kubectl logs -f provider-azure-containerservice-xxx -n crossplane-system
```

## Supported API Versions

Use one of these supported API versions:

- `2025-04-01` (Latest)
- `2025-03-01`
- `2024-11-01` (Recommended)
- `2024-08-01`
- `2024-07-01`
- `2023-07-01`

## Verification

Check that the provider is using the correct API version:

```bash
# Check provider logs for API version
kubectl logs provider-azure-containerservice-xxx -n crossplane-system | grep "api-version"

# Test cluster creation
kubectl apply -f test-cluster-claim.yaml
```

## Fallback Solutions

If the API version override doesn't work:

### Option 1: Use Terraform Instead

```bash
# Use Terraform for AKS provisioning
cd terraform
terraform plan -var="cluster_name=aks-fixed-cluster"
terraform apply
```

### Option 2: Use Azure CLI

```bash
# Direct Azure CLI provisioning
az aks create \
  --resource-group rg-aks-fixed \
  --name aks-fixed-cluster \
  --node-count 2 \
  --api-server-authorized-ip-ranges 0.0.0.0/0
```

### Option 3: Wait for Provider Update

Monitor the Crossplane Azure provider releases for updates that use supported API versions.

## Troubleshooting

### Check Current API Version

```bash
# Check what API version is being used
kubectl logs provider-azure-containerservice-xxx -n crossplane-system | grep "api-version"
```

### Verify Environment Variables

```bash
# Check if environment variables are set
kubectl exec provider-azure-containerservice-xxx -n crossplane-system -- env | grep API
```

### Test API Version Support

```bash
# Test if the API version is supported in your region
az rest --method GET \
  --url "https://management.azure.com/subscriptions/{subscription-id}/providers/Microsoft.ContainerService?api-version=2024-11-01"
```

## References

- [Azure AKS API Versions](https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions)
- [Crossplane Azure Provider](https://marketplace.upbound.io/providers/crossplane-contrib/provider-azure)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) 