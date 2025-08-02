# ArgoCD Ingress Configuration

This document describes how to configure ArgoCD to use nginx ingress controller for external access instead of LoadBalancer services.

## Overview

ArgoCD is configured to use nginx ingress controller for external access, providing:
- **Domain-based access**: Access ArgoCD via domain names instead of IP addresses
- **TLS termination**: Secure HTTPS access with automatic SSL redirect
- **Environment-specific domains**: Different domains for different environments
- **Security headers**: Additional security headers for enhanced protection

## Architecture

### Ingress Configuration

ArgoCD uses nginx ingress controller with the following configuration:

- **Ingress Class**: `nginx`
- **Backend Protocol**: `HTTPS` (SSL passthrough)
- **TLS**: Self-signed certificates for development
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection

### Domain Configuration

| Environment | Domain | Rate Limit | Security Level |
|-------------|--------|------------|----------------|
| Control-Plane | `argocd.poc.westus3.mckesson.com` | 100 req/min | Enhanced |
| Development | `argocd.poc-dev.westus3.mckesson.com` | 50 req/min | Basic |
| Production | `argocd.poc-prod.westus3.mckesson.com` | 200 req/min | High |

## Installation

### 1. Generate TLS Certificates

Before deploying, generate TLS certificates for ArgoCD:

```bash
# Generate certificates for all environments
./dev/generate-argocd-cert.sh
```

This script creates:
- Private keys and certificates for all three domains
- Kubernetes secret manifests for each environment
- Self-signed certificates valid for 365 days

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

### 3. Deploy ArgoCD with Ingress

The ArgoCD configuration is automatically applied when you deploy the platform. The ingress configuration is included in the Helm values.

## Configuration Details

### Default Configuration

```yaml
server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
      nginx.ingress.kubernetes.io/configuration-snippet: |
        more_set_headers "X-Frame-Options DENY";
        more_set_headers "X-Content-Type-Options nosniff";
        more_set_headers "X-XSS-Protection 1; mode=block";
    hosts:
      - host: argocd.poc.westus3.mckesson.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.poc.westus3.mckesson.com
```

### Environment-Specific Configurations

#### Control-Plane Environment

```yaml
server:
  ingress:
    annotations:
      # ... standard annotations ...
      nginx.ingress.kubernetes.io/rate-limit: "100"
      nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    hosts:
      - host: argocd.poc.westus3.mckesson.com
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.poc.westus3.mckesson.com
```

#### Development Environment

```yaml
server:
  ingress:
    annotations:
      # ... standard annotations ...
      nginx.ingress.kubernetes.io/rate-limit: "50"
      nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    hosts:
      - host: argocd.poc-dev.westus3.mckesson.com
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.poc-dev.westus3.mckesson.com
```

#### Production Environment

```yaml
server:
  ingress:
    annotations:
      # ... standard annotations ...
      nginx.ingress.kubernetes.io/rate-limit: "200"
      nginx.ingress.kubernetes.io/rate-limit-window: "1m"
      nginx.ingress.kubernetes.io/configuration-snippet: |
        more_set_headers "X-Frame-Options DENY";
        more_set_headers "X-Content-Type-Options nosniff";
        more_set_headers "X-XSS-Protection 1; mode=block";
        more_set_headers "Strict-Transport-Security max-age=31536000; includeSubDomains";
        more_set_headers "Content-Security-Policy default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';";
    hosts:
      - host: argocd.poc-prod.westus3.mckesson.com
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.poc-prod.westus3.mckesson.com
```

## Usage

### Accessing ArgoCD

1. **Configure DNS** (if needed):
   ```bash
   # Get the nginx ingress controller external IP
   EXTERNAL_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   
   # Configure DNS to point the appropriate domain to this IP:
   # - Control-plane: argocd.poc.westus3.mckesson.com
   # - Development: argocd.poc-dev.westus3.mckesson.com
   # - Production: argocd.poc-prod.westus3.mckesson.com
   
   # Or add to /etc/hosts for local testing:
   echo "$EXTERNAL_IP argocd.poc.westus3.mckesson.com" | sudo tee -a /etc/hosts
   echo "$EXTERNAL_IP argocd.poc-dev.westus3.mckesson.com" | sudo tee -a /etc/hosts
   echo "$EXTERNAL_IP argocd.poc-prod.westus3.mckesson.com" | sudo tee -a /etc/hosts
   ```

2. **Access ArgoCD**:
   - Control-plane: `https://argocd.poc.westus3.mckesson.com`
   - Development: `https://argocd.poc-dev.westus3.mckesson.com`
   - Production: `https://argocd.poc-prod.westus3.mckesson.com`
   - Accept the self-signed certificate warning
   - Login with ArgoCD credentials

### Getting ArgoCD Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Security Considerations

### TLS Configuration

- **Self-signed certificates**: Used for development environments
- **Production certificates**: Should use proper CA-signed certificates
- **Certificate renewal**: Certificates expire after 365 days

### Security Headers

The ingress configuration includes several security headers:

- **X-Frame-Options**: Prevents clickjacking attacks
- **X-Content-Type-Options**: Prevents MIME type sniffing
- **X-XSS-Protection**: Basic XSS protection
- **Strict-Transport-Security**: Enforces HTTPS (production only)
- **Content-Security-Policy**: Restricts resource loading (production only)

### Rate Limiting

Different environments have different rate limits:

- **Development**: 50 requests per minute
- **Control-Plane**: 100 requests per minute
- **Production**: 200 requests per minute

## Troubleshooting

### Common Issues

1. **Certificate errors**:
   ```bash
   # Check if TLS secret exists
   kubectl get secret argocd-tls -n argocd
   
   # Check certificate validity
   kubectl get secret argocd-tls -n argocd -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
   ```

2. **Ingress not working**:
   ```bash
   # Check ingress status
   kubectl get ingress -n argocd
   kubectl describe ingress argocd-server -n argocd
   
   # Check nginx ingress controller logs
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

3. **SSL passthrough issues**:
   ```bash
   # Verify SSL passthrough configuration
   kubectl get configmap -n ingress-nginx nginx-configuration -o yaml
   ```

### Useful Commands

```bash
# Check ArgoCD service
kubectl get service argocd-server -n argocd

# Check ArgoCD ingress
kubectl get ingress -n argocd

# Check TLS secret
kubectl get secret argocd-tls -n argocd

# Test connectivity for different environments
curl -k -H "Host: argocd.poc.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: argocd.poc-dev.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k -H "Host: argocd.poc-prod.westus3.mckesson.com" https://$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## Production Considerations

### Certificate Management

For production environments:

1. **Use proper CA-signed certificates**:
   ```bash
   # Replace self-signed certificates with CA-signed ones
   kubectl create secret tls argocd-tls \
     --cert=path/to/certificate.crt \
     --key=path/to/private.key \
     --namespace=argocd
   ```

2. **Set up certificate renewal**:
   - Use cert-manager for automatic certificate renewal
   - Monitor certificate expiration dates
   - Set up alerts for expiring certificates

### Monitoring

1. **Set up monitoring for ArgoCD**:
   - Monitor ingress controller metrics
   - Set up alerts for certificate expiration
   - Monitor rate limiting and access patterns

2. **Logging**:
   - Enable access logging for ArgoCD ingress
   - Monitor for suspicious access patterns
   - Set up log aggregation and analysis

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [TLS Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
- [SSL Passthrough](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#ssl-passthrough) 