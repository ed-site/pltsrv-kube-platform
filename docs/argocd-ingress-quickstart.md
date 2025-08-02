# ArgoCD Ingress Quick Start Guide

This guide provides step-by-step instructions for setting up ArgoCD with nginx ingress controller for external access.

## Prerequisites

- Kubernetes cluster with ArgoCD and nginx ingress controller installed
- Access to the cluster for applying configurations
- OpenSSL installed for certificate generation

## Quick Start

### 1. Generate TLS Certificates

Generate TLS certificates for ArgoCD ingress:

```bash
# Generate certificates for all environments
./dev/generate-argocd-cert.sh
```

This creates certificates for:
- `argocd.poc.westus3.mckesson.com` (control-plane)
- `argocd.poc-dev.westus3.mckesson.com` (development)
- `argocd.poc-prod.westus3.mckesson.com` (production)

### 2. Apply TLS Secrets

Apply the TLS secrets to your cluster:

```bash
# For control-plane environment
kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc.westus3.mckesson.com.yaml

# For development environment
kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc-dev.westus3.mckesson.com.yaml

# For production environment
kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc-prod.westus3.mckesson.com.yaml
```

### 3. Verify ArgoCD Configuration

Check that ArgoCD is configured with ingress:

```bash
# Check ArgoCD deployment
kubectl get deployment argocd-server -n argocd

# Check ArgoCD service (should be ClusterIP)
kubectl get service argocd-server -n argocd

# Check ArgoCD ingress
kubectl get ingress -n argocd
```

### 4. Configure Local Access

Configure DNS or add to hosts file for access:

```bash
# Get the nginx ingress controller external IP
EXTERNAL_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Configure DNS to point the appropriate domains to this IP:
# - Control-plane: argocd.poc.westus3.mckesson.com
# - Development: argocd.poc-dev.westus3.mckesson.com
# - Production: argocd.poc-prod.westus3.mckesson.com

# Or add to /etc/hosts for local testing (Linux/Mac):
echo "$EXTERNAL_IP argocd.poc.westus3.mckesson.com" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP argocd.poc-dev.westus3.mckesson.com" | sudo tee -a /etc/hosts
echo "$EXTERNAL_IP argocd.poc-prod.westus3.mckesson.com" | sudo tee -a /etc/hosts

# For Windows, add to C:\Windows\System32\drivers\etc\hosts
# $EXTERNAL_IP argocd.poc.westus3.mckesson.com
# $EXTERNAL_IP argocd.poc-dev.westus3.mckesson.com
# $EXTERNAL_IP argocd.poc-prod.westus3.mckesson.com
```

### 5. Access ArgoCD

1. **Open your browser** and navigate to the appropriate URL:
   - Control-plane: `https://argocd.poc.westus3.mckesson.com`
   - Development: `https://argocd.poc-dev.westus3.mckesson.com`
   - Production: `https://argocd.poc-prod.westus3.mckesson.com`
2. **Accept the certificate warning** (self-signed certificate)
3. **Login with ArgoCD credentials**:
   - Username: `admin`
   - Password: Get it with the command below

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Environment-Specific Configuration

### Environment Configuration

Each environment uses its own domain with environment-specific configurations:
- Control-plane: `argocd.poc.westus3.mckesson.com` (100 req/min, enhanced security)
- Development: `argocd.poc-dev.westus3.mckesson.com` (50 req/min, basic security)
- Production: `argocd.poc-prod.westus3.mckesson.com` (200 req/min, high security)

## Testing

### Test Ingress Configuration

```bash
# Test the ingress endpoints
curl -k -H "Host: argocd.poc.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: argocd.poc-dev.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: argocd.poc-prod.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Check ingress status
kubectl describe ingress argocd-server -n argocd
```

### Test TLS Configuration

```bash
# Check TLS secret
kubectl get secret argocd-tls -n argocd

# Verify certificate
kubectl get secret argocd-tls -n argocd -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## Troubleshooting

### Common Issues

1. **Certificate errors**:
   ```bash
   # Check if TLS secret exists
   kubectl get secret argocd-tls -n argocd
   
   # Recreate if missing
kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc.westus3.mckesson.com.yaml
kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc-dev.westus3.mckesson.com.yaml
kubectl apply -f dev/certs/argocd/argocd-tls-secret-argocd.poc-prod.westus3.mckesson.com.yaml
   ```

2. **Ingress not working**:
   ```bash
   # Check ingress status
   kubectl get ingress -n argocd
   kubectl describe ingress argocd-server -n argocd
   
   # Check nginx ingress controller
   kubectl get pods -n ingress-nginx
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

3. **SSL passthrough issues**:
   ```bash
   # Check nginx configuration
   kubectl get configmap -n ingress-nginx nginx-configuration -o yaml
   
   # Restart nginx ingress controller
   kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
   ```

### Useful Commands

```bash
# Check all ArgoCD resources
kubectl get all -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test connectivity for different environments
curl -k -H "Host: argocd.poc.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: argocd.poc-dev.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: argocd.poc-prod.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## Security Notes

### Development vs Production

- **Development**: Uses self-signed certificates (acceptable for development)
- **Production**: Should use proper CA-signed certificates

### Certificate Renewal

- Self-signed certificates expire after 365 days
- Monitor certificate expiration and renew before expiry
- Consider using cert-manager for automatic renewal

### Security Headers

The configuration includes security headers:
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- HSTS and CSP (production only)

## Next Steps

- [Read the full ArgoCD ingress documentation](argocd-ingress-configuration.md)
- [Configure production certificates](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
- [Set up monitoring and alerts](https://argo-cd.readthedocs.io/en/stable/operator-manual/monitoring/)
- [Configure RBAC and access control](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/) 