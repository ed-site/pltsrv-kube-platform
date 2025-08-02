# Cert-Manager Quick Start Guide

This guide provides step-by-step instructions for setting up cert-manager with ACME (Let's Encrypt) for automatic TLS certificate management.

## Prerequisites

- Kubernetes cluster with ArgoCD and nginx ingress controller installed
- GitOps Bridge pattern already configured
- Access to the cluster for applying configurations
- DNS control for your domains (for DNS-01 challenges)

## Quick Start

### 1. Enable Cert-Manager on Control-Plane Cluster

Cert-manager is automatically installed on the control-plane cluster. To verify:

```bash
# Check if the ApplicationSet exists
kubectl get applicationset -n argocd addons-cert-manager

# Check if the application is deployed
kubectl get application -n argocd addon-control-plane-cert-manager

# Check if cert-manager is running
kubectl get pods -n cert-manager
```

### 2. Enable Cert-Manager on Workload Cluster

To enable cert-manager on a workload cluster, add the appropriate labels to the cluster resource:

```yaml
apiVersion: v1
kind: Cluster
metadata:
  name: your-workload-cluster
  labels:
    enable_cert_manager: "true"
    environment: "dev"  # or "prod"
    cert_manager_chart_version: "1.13.3"
  annotations:
    addons_repo_url: "https://github.com/your-org/your-repo"
    addons_repo_basepath: "gitops/"
    addons_repo_revision: "main"
spec:
  server: "https://your-workload-cluster-api-server:6443"
  # ... other cluster configuration
```

### 3. Apply the Cluster Configuration

```bash
# Apply the cluster configuration
kubectl apply -f cluster-config.yaml

# Verify the cluster is registered
kubectl get cluster your-workload-cluster
```

### 4. Monitor the Deployment

```bash
# Check if the ApplicationSet created the application
kubectl get application -n argocd | grep cert-manager

# Check the application status
kubectl describe application addon-your-workload-cluster-cert-manager -n argocd

# Check if cert-manager is running
kubectl get pods -n cert-manager
```

### 5. Configure ClusterIssuers

After cert-manager is installed, configure ClusterIssuers for ACME:

```bash
# Apply ClusterIssuer resources
kubectl apply -f gitops/environments/default/addons/cert-manager/cluster-issuers.yaml

# Verify ClusterIssuers are ready
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-prod
```

## Configuration

### Update ClusterIssuer Configuration

Before applying ClusterIssuers, update the configuration with your specific values:

1. **Edit the ClusterIssuer file**:
   ```bash
   # Edit the ClusterIssuer configuration
   kubectl edit -f gitops/environments/default/addons/cert-manager/cluster-issuers.yaml
   ```

2. **Update the following values**:
   - `email`: Your email address for Let's Encrypt notifications
   - `subscriptionID`: Your Azure subscription ID
   - `resourceGroupName`: Your Azure resource group name
   - `hostedZoneName`: Your DNS zone name
   - `clientID`: Your managed identity client ID

### Environment-Specific Configuration

You can customize cert-manager for different environments:

1. **Development Environment**:
   ```bash
   # Edit the dev environment values
   kubectl edit configmap -n argocd addon-your-workload-cluster-cert-manager
   ```

2. **Production Environment**:
   ```bash
   # Edit the prod environment values
   kubectl edit configmap -n argocd addon-your-workload-cluster-cert-manager
   ```

## Testing

### 1. Create a Test Certificate

Create a test certificate to verify cert-manager is working:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: default
spec:
  secretName: test-certificate-tls
  issuerRef:
    name: letsencrypt-staging  # Use staging for testing
    kind: ClusterIssuer
  dnsNames:
    - test.example.com
```

### 2. Apply the Test Certificate

```bash
# Apply the test certificate
kubectl apply -f test-certificate.yaml

# Check certificate status
kubectl get certificate test-certificate -n default
kubectl describe certificate test-certificate -n default
```

### 3. Monitor Certificate Creation

```bash
# Watch certificate status
kubectl get certificate test-certificate -n default -w

# Check certificate events
kubectl get events --field-selector involvedObject.name=test-certificate -n default

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f
```

### 4. Verify Certificate Creation

```bash
# Check if the secret was created
kubectl get secret test-certificate-tls -n default

# Verify certificate details
kubectl get secret test-certificate-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## Usage Examples

### 1. ArgoCD Certificate

Apply the ArgoCD certificate for automatic TLS:

```bash
# Apply ArgoCD certificate
kubectl apply -f gitops/environments/default/addons/argo-cd/certificate.yaml

# Check certificate status
kubectl get certificate argocd-tls -n argocd
```

### 2. Application Certificate

Create a certificate for your application:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: my-app
spec:
  secretName: my-app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - my-app.example.com
```

### 3. Wildcard Certificate

Create a wildcard certificate using DNS-01 challenge:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: default
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.example.com"
    - example.com
```

## Troubleshooting

### Common Issues

1. **Certificate not issued**:
   ```bash
   # Check certificate status
   kubectl describe certificate my-certificate -n my-namespace
   
   # Check cert-manager logs
   kubectl logs -n cert-manager deployment/cert-manager
   
   # Check ClusterIssuer status
   kubectl describe clusterissuer letsencrypt-prod
   ```

2. **ACME challenge failed**:
   ```bash
   # Check challenge status
   kubectl get challenges --all-namespaces
   
   # Check ingress configuration
   kubectl describe ingress my-ingress
   
   # Verify DNS resolution
   nslookup my-domain.example.com
   ```

3. **Rate limiting**:
   ```bash
   # Check Let's Encrypt rate limits
   # Use staging environment for testing
   kubectl patch certificate my-certificate -n my-namespace -p '{"spec":{"issuerRef":{"name":"letsencrypt-staging"}}}'
   ```

### Useful Commands

```bash
# Check cert-manager components
kubectl get pods -n cert-manager

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
kubectl logs -n cert-manager deployment/cert-manager-webhook
kubectl logs -n cert-manager deployment/cert-manager-cainjector

# Check ClusterIssuers
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-prod

# Check certificates
kubectl get certificates --all-namespaces
kubectl describe certificate my-certificate -n my-namespace

# Check certificate requests
kubectl get certificaterequests --all-namespaces

# Check orders (ACME)
kubectl get orders --all-namespaces

# Check challenges (ACME)
kubectl get challenges --all-namespaces
```

## Security Notes

### Development vs Production

- **Development**: Use `letsencrypt-staging` for testing (no rate limits)
- **Production**: Use `letsencrypt-prod` for production certificates

### Rate Limiting

- Let's Encrypt has rate limits (50 certificates per registered domain per week)
- Use staging environment for testing
- Monitor certificate requests

### Certificate Renewal

- Certificates are automatically renewed before expiration
- Monitor certificate expiration dates
- Set up alerts for certificate failures

## Next Steps

- [Read the full cert-manager documentation](cert-manager-gitops-bridge.md)
- [Configure DNS provider for DNS-01 challenges](https://cert-manager.io/docs/configuration/acme/dns01/)
- [Set up monitoring and alerting](https://cert-manager.io/docs/installation/verify/)
- [Configure backup and recovery](https://cert-manager.io/docs/installation/backup/) 