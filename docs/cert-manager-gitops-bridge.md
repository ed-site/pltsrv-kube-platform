# Cert-Manager with ACME - GitOps Bridge Installation

This document describes how to install and configure cert-manager with ACME (Let's Encrypt) as a bootstrapping addon for both control-plane and workload clusters using the GitOps Bridge pattern.

## Overview

Cert-manager is installed as a GitOps-managed addon that provides automatic TLS certificate management using ACME (Let's Encrypt). It can be deployed to:
- Control-plane clusters (for centralized certificate management)
- Workload clusters (for distributed certificate management)

The installation follows the [GitOps Bridge pattern](https://github.com/gitops-bridge-dev/gitops-bridge) to bridge Infrastructure as Code (IaC) metadata with GitOps deployment.

## Architecture

### Cert-Manager Components

- **Controller**: Manages certificate lifecycle and renewal
- **Webhook**: Validates cert-manager resources
- **CA Injector**: Injects CA bundles into webhook configurations

### ACME Integration

- **HTTP-01 Challenge**: For domain validation using HTTP requests
- **DNS-01 Challenge**: For wildcard certificates using DNS records
- **Let's Encrypt**: Production and staging environments

## Installation

### 1. Control-Plane Cluster

Cert-manager is automatically installed on the control-plane cluster when you deploy the platform. The configuration is defined in:

- **ApplicationSet**: `gitops/bootstrap/control-plane/addons/oss/addons-cert-manager-appset.yaml`
- **Default Values**: `gitops/environments/default/addons/cert-manager/values.yaml`
- **Control-Plane Values**: `gitops/environments/control-plane/addons/cert-manager/values.yaml`

### 2. Workload Clusters

To enable cert-manager on workload clusters, you need to:

1. **Add cluster labels** to enable the addon:
   ```yaml
   apiVersion: v1
   kind: Cluster
   metadata:
     name: your-workload-cluster
     labels:
       enable_cert_manager: "true"
       environment: "dev"  # or "prod"
       cert_manager_chart_version: "1.13.3"
   ```

2. **Create environment-specific values** (optional):
   - `gitops/environments/dev/addons/cert-manager/values.yaml`
   - `gitops/environments/prod/addons/cert-manager/values.yaml`
   - `gitops/environments/clusters/{cluster-name}/addons/cert-manager/values.yaml`

## Configuration

### Default Configuration

The default configuration includes:

- **CRDs Installation**: Automatic installation of cert-manager CRDs
- **Security**: Non-root containers, security contexts, and RBAC
- **Monitoring**: Prometheus metrics enabled
- **High Availability**: Pod Disruption Budget enabled
- **Prometheus Integration**: ServiceMonitor for monitoring

### Environment-Specific Configurations

#### Control-Plane
- **Controller Replicas**: 2
- **Resources**: Higher allocation (200m-500m CPU, 256Mi-512Mi memory)
- **Pod Disruption Budget**: minAvailable: 1

#### Development
- **Controller Replicas**: 1
- **Resources**: Standard allocation (100m-200m CPU, 128Mi-256Mi memory)
- **Pod Disruption Budget**: minAvailable: 1

#### Production
- **Controller Replicas**: 3
- **Resources**: High allocation (300m-1000m CPU, 512Mi-1Gi memory)
- **Pod Disruption Budget**: minAvailable: 2

## ACME Configuration

### ClusterIssuer Resources

Cert-manager uses ClusterIssuer resources to configure ACME providers:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@mckesson.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
    - dns01:
        azureDNS:
          subscriptionID: "your-subscription-id"
          resourceGroupName: "your-resource-group"
          hostedZoneName: "westus3.mckesson.com"
          environment: AzurePublicCloud
          managedIdentity:
            clientID: "your-managed-identity-client-id"
```

### Certificate Resources

Certificates are defined using Certificate resources:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-tls
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  commonName: argocd.poc.westus3.mckesson.com
  dnsNames:
    - argocd.poc.westus3.mckesson.com
    - argocd.poc-dev.westus3.mckesson.com
    - argocd.poc-prod.westus3.mckesson.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  usages:
    - digital signature
    - key encipherment
    - server auth
```

## Usage

### Creating Certificates

1. **Define a Certificate resource**:
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

2. **Use the certificate in Ingress**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: my-app-ingress
     annotations:
       kubernetes.io/ingress.class: nginx
   spec:
     tls:
     - hosts:
       - my-app.example.com
       secretName: my-app-tls
     rules:
     - host: my-app.example.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: my-app-service
               port:
                 number: 80
   ```

### Certificate Management

Cert-manager automatically:
- **Requests certificates** from Let's Encrypt
- **Validates domain ownership** using HTTP-01 or DNS-01 challenges
- **Renews certificates** before expiration
- **Updates Kubernetes secrets** with new certificates

## Monitoring

### Metrics

Cert-manager exposes Prometheus metrics on port 9402. You can scrape these metrics for monitoring:

- **Endpoint**: `/metrics`
- **Port**: `9402`
- **Annotations**: Already configured for Prometheus scraping

### Certificate Status

Check certificate status:

```bash
# List all certificates
kubectl get certificates --all-namespaces

# Check certificate details
kubectl describe certificate my-app-tls -n my-app

# Check certificate events
kubectl get events --field-selector involvedObject.name=my-app-tls -n my-app
```

## Troubleshooting

### Common Issues

1. **Certificate not issued**:
   ```bash
   # Check certificate status
   kubectl describe certificate my-app-tls -n my-app
   
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
   kubectl describe ingress my-app-ingress
   
   # Verify DNS resolution
   nslookup my-app.example.com
   ```

3. **Rate limiting**:
   - Let's Encrypt has rate limits (50 certificates per registered domain per week)
   - Use staging environment for testing
   - Monitor certificate requests

### Useful Commands

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ClusterIssuers
kubectl get clusterissuers

# Check certificates
kubectl get certificates --all-namespaces

# Check certificate requests
kubectl get certificaterequests --all-namespaces

# Check orders (ACME)
kubectl get orders --all-namespaces

# Check challenges (ACME)
kubectl get challenges --all-namespaces
```

## Security Considerations

### ACME Account Security

- **Private keys**: Stored securely in Kubernetes secrets
- **Email notifications**: Configure for certificate expiration
- **Rate limiting**: Monitor Let's Encrypt rate limits

### Network Security

- **Ingress access**: Ensure ingress controller is accessible for HTTP-01 challenges
- **DNS access**: Configure DNS provider credentials for DNS-01 challenges
- **Firewall rules**: Allow cert-manager to reach Let's Encrypt servers

### Certificate Security

- **Certificate rotation**: Automatic renewal before expiration
- **Secret management**: Certificates stored as Kubernetes secrets
- **RBAC**: Cert-manager runs with minimal required permissions

## Production Considerations

### DNS Configuration

For production environments:

1. **Configure DNS provider**:
   - Azure DNS with managed identity
   - AWS Route53 with IAM roles
   - Cloudflare with API tokens

2. **Set up DNS-01 challenges** for wildcard certificates:
   ```yaml
   solvers:
   - dns01:
       azureDNS:
         subscriptionID: "your-subscription-id"
         resourceGroupName: "your-resource-group"
         hostedZoneName: "westus3.mckesson.com"
         environment: AzurePublicCloud
         managedIdentity:
           clientID: "your-managed-identity-client-id"
   ```

### Monitoring and Alerting

1. **Set up monitoring**:
   - Monitor certificate expiration
   - Alert on certificate failures
   - Track certificate renewal success rates

2. **Logging**:
   - Enable cert-manager logging
   - Monitor ACME challenge logs
   - Track certificate request patterns

### Backup and Recovery

1. **Backup ACME account keys**:
   ```bash
   kubectl get secret letsencrypt-prod -o yaml > letsencrypt-prod-backup.yaml
   ```

2. **Backup certificates**:
   ```bash
   kubectl get certificates --all-namespaces -o yaml > certificates-backup.yaml
   ```

## References

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [ACME Protocol](https://tools.ietf.org/html/rfc8555)
- [GitOps Bridge Pattern](https://github.com/gitops-bridge-dev/gitops-bridge)
- [Helm Chart Repository](https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager) 