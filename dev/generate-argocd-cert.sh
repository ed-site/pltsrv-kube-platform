#!/bin/bash

# Generate TLS certificates for ArgoCD ingress
# This script creates certificates for different environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Generating TLS certificates for ArgoCD ingress...${NC}"

# Create certs directory if it doesn't exist
mkdir -p dev/certs/argocd

# Function to generate certificate for a domain
generate_cert() {
    local domain=$1
    local cert_dir="dev/certs/argocd"
    
    echo -e "${YELLOW}Generating certificate for ${domain}...${NC}"
    
    # Generate private key
    openssl genrsa -out "${cert_dir}/${domain}.key" 2048
    
    # Generate certificate signing request
    openssl req -new -key "${cert_dir}/${domain}.key" -out "${cert_dir}/${domain}.csr" -subj "/CN=${domain}/O=ArgoCD/C=US/ST=CA/L=San Francisco"
    
    # Generate self-signed certificate
    openssl x509 -req -in "${cert_dir}/${domain}.csr" -signkey "${cert_dir}/${domain}.key" -out "${cert_dir}/${domain}.crt" -days 365 -extensions v3_req -extfile <(
        cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${domain}
O = ArgoCD
C = US
ST = CA
L = San Francisco

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = *.${domain}
EOF
    )
    
    echo -e "${GREEN}Certificate generated for ${domain}${NC}"
}

# Generate certificates for different environments
generate_cert "argocd.poc.westus3.mckesson.com"        # Control-plane
generate_cert "argocd.poc-dev.westus3.mckesson.com"    # Development
generate_cert "argocd.poc-prod.westus3.mckesson.com"   # Production

echo -e "${GREEN}All certificates generated successfully!${NC}"
echo -e "${YELLOW}Certificates are located in: dev/certs/argocd/${NC}"

# Create Kubernetes secrets
echo -e "${YELLOW}Creating Kubernetes secrets...${NC}"

# Function to create secret for a domain
create_secret() {
    local domain=$1
    local cert_dir="dev/certs/argocd"
    
    echo -e "${YELLOW}Creating secret for ${domain}...${NC}"
    
    # Create the secret
    kubectl create secret tls argocd-tls \
        --cert="${cert_dir}/${domain}.crt" \
        --key="${cert_dir}/${domain}.key" \
        --namespace=argocd \
        --dry-run=client -o yaml > "${cert_dir}/argocd-tls-secret-${domain}.yaml"
    
    echo -e "${GREEN}Secret manifest created: ${cert_dir}/argocd-tls-secret-${domain}.yaml${NC}"
}

# Create secrets for different environments
create_secret "argocd.poc.westus3.mckesson.com"        # Control-plane
create_secret "argocd.poc-dev.westus3.mckesson.com"    # Development
create_secret "argocd.poc-prod.westus3.mckesson.com"   # Production

echo -e "${GREEN}All secret manifests created!${NC}"
echo -e "${YELLOW}To apply the secrets, run:${NC}"
echo -e "kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc.westus3.mckesson.com.yaml"
echo -e "kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc-dev.westus3.mckesson.com.yaml"
echo -e "kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc-prod.westus3.mckesson.com.yaml" 