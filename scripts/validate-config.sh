#!/bin/bash

# Configuration Validation Script
# This script validates YAML syntax, Kubernetes resource validity, and configuration consistency

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Starting Configuration Validation...${NC}"

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to print success/failure messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Validate YAML Syntax
print_section "YAML Syntax Validation"

# Check if yamllint is available
if command -v yamllint &> /dev/null; then
    echo "Validating YAML files with yamllint..."
    find gitops/ -name "*.yaml" -type f | while read -r file; do
        if yamllint "$file" > /dev/null 2>&1; then
            print_success "YAML syntax valid: $file"
        else
            print_error "YAML syntax error in: $file"
            yamllint "$file"
        fi
    done
else
    print_warning "yamllint not found, skipping YAML syntax validation"
fi

# 2. Validate Kubernetes Resource Definitions
print_section "Kubernetes Resource Validation"

# Function to validate a YAML file
validate_k8s_resource() {
    local file="$1"
    local resource_type="$2"
    
    if [[ -f "$file" ]]; then
        if kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
            print_success "Valid $resource_type: $file"
        else
            print_error "Invalid $resource_type: $file"
            kubectl apply --dry-run=client -f "$file" 2>&1 | head -10
        fi
    else
        print_warning "File not found: $file"
    fi
}

# Validate ApplicationSets
echo "Validating ApplicationSets..."
validate_k8s_resource "gitops/bootstrap/control-plane/addons/oss/addons-nginx-ingress-appset.yaml" "ApplicationSet"
validate_k8s_resource "gitops/bootstrap/control-plane/addons/oss/addons-cert-manager-appset.yaml" "ApplicationSet"

# Validate ClusterIssuers (will fail if cert-manager not installed, which is expected)
echo "Validating ClusterIssuers..."
validate_k8s_resource "gitops/environments/default/addons/cert-manager/cluster-issuers.yaml" "ClusterIssuer"

# Validate Certificate resources
echo "Validating Certificate resources..."
validate_k8s_resource "gitops/environments/default/addons/argo-cd/certificate.yaml" "Certificate"

# 3. Validate Helm Values Files
print_section "Helm Values Validation"

# Function to validate Helm values
validate_helm_values() {
    local file="$1"
    local chart_name="$2"
    
    if [[ -f "$file" ]]; then
        if helm template test-release "$chart_name" -f "$file" > /dev/null 2>&1; then
            print_success "Valid Helm values: $file"
        else
            print_error "Invalid Helm values: $file"
        fi
    else
        print_warning "File not found: $file"
    fi
}

# Validate nginx ingress values
echo "Validating nginx ingress values..."
validate_helm_values "gitops/environments/default/addons/ingress-nginx/values.yaml" "ingress-nginx"
validate_helm_values "gitops/environments/control-plane/addons/ingress-nginx/values.yaml" "ingress-nginx"
validate_helm_values "gitops/environments/dev/addons/ingress-nginx/values.yaml" "ingress-nginx"
validate_helm_values "gitops/environments/prod/addons/ingress-nginx/values.yaml" "ingress-nginx"

# Validate cert-manager values
echo "Validating cert-manager values..."
validate_helm_values "gitops/environments/default/addons/cert-manager/values.yaml" "cert-manager"
validate_helm_values "gitops/environments/control-plane/addons/cert-manager/values.yaml" "cert-manager"
validate_helm_values "gitops/environments/dev/addons/cert-manager/values.yaml" "cert-manager"
validate_helm_values "gitops/environments/prod/addons/cert-manager/values.yaml" "cert-manager"

# Validate ArgoCD values
echo "Validating ArgoCD values..."
validate_helm_values "gitops/environments/default/addons/argo-cd/values.yaml" "argo-cd"
validate_helm_values "gitops/environments/control-plane/addons/argo-cd/values.yaml" "argo-cd"
validate_helm_values "gitops/environments/dev/addons/argo-cd/values.yaml" "argo-cd"
validate_helm_values "gitops/environments/prod/addons/argo-cd/values.yaml" "argo-cd"

# 4. Configuration Consistency Checks
print_section "Configuration Consistency Validation"

# Check if all required files exist
echo "Checking required files..."
required_files=(
    "gitops/bootstrap/control-plane/addons/oss/addons-nginx-ingress-appset.yaml"
    "gitops/bootstrap/control-plane/addons/oss/addons-cert-manager-appset.yaml"
    "gitops/environments/default/addons/ingress-nginx/values.yaml"
    "gitops/environments/default/addons/cert-manager/values.yaml"
    "gitops/environments/default/addons/argo-cd/values.yaml"
    "gitops/environments/default/addons/cert-manager/cluster-issuers.yaml"
    "gitops/environments/default/addons/argo-cd/certificate.yaml"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "Required file exists: $file"
    else
        print_error "Required file missing: $file"
    fi
done

# Check domain consistency in ArgoCD configurations
echo "Checking domain consistency..."
grep -r "argocd.poc" gitops/environments/*/addons/argo-cd/values.yaml | while read -r line; do
    if [[ "$line" =~ argocd\.poc ]]; then
        print_success "Domain found: $line"
    else
        print_error "Unexpected domain format: $line"
    fi
done

# 5. Terraform Configuration Validation
print_section "Terraform Configuration Validation"

if [[ -d "terraform" ]]; then
    cd terraform
    if terraform validate > /dev/null 2>&1; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration has errors"
        terraform validate
    fi
    cd ..
else
    print_warning "Terraform directory not found"
fi

# 6. Check for Common Issues
print_section "Common Issues Check"

# Check for hardcoded values that should be templated
echo "Checking for hardcoded values..."
if grep -r "your-subscription-id\|your-resource-group\|your-managed-identity" gitops/; then
    print_warning "Found placeholder values that need to be replaced"
else
    print_success "No placeholder values found"
fi

# Check for proper annotations
echo "Checking for required annotations..."
if grep -r "source: gitops-bridge" gitops/; then
    print_success "GitOps Bridge annotations found"
else
    print_warning "GitOps Bridge annotations missing in some files"
fi

# 7. Summary
print_section "Validation Summary"

echo -e "${GREEN}🎉 Configuration validation completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Review any warnings or errors above"
echo "2. Replace placeholder values in ClusterIssuer configuration"
echo "3. Deploy the infrastructure with: terraform apply"
echo "4. Monitor ArgoCD applications for successful deployment"
echo "5. Test certificate issuance with cert-manager"

echo ""
echo -e "${BLUE}For more information, see the documentation:${NC}"
echo "- docs/nginx-ingress-gitops-bridge.md"
echo "- docs/cert-manager-gitops-bridge.md"
echo "- docs/argocd-ingress-configuration.md" 