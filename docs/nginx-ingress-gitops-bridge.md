# Nginx Ingress Controller - GitOps Bridge Installation

This document describes how to install and configure the Nginx Ingress Controller as a bootstrapping addon for both control-plane and workload clusters using the GitOps Bridge pattern.

## Overview

The Nginx Ingress Controller is installed as a GitOps-managed addon that can be deployed to:
- Control-plane clusters (for centralized ingress management)
- Workload clusters (for distributed ingress management)

The installation follows the [GitOps Bridge pattern](https://github.com/gitops-bridge-dev/gitops-bridge) to bridge Infrastructure as Code (IaC) metadata with GitOps deployment.

## Architecture

### Control-Plane Cluster
- **Purpose**: Centralized ingress management for the platform
- **Configuration**: Higher resource allocation and replica count
- **Load Balancer**: External Azure Load Balancer with Standard SKU

### Workload Clusters
- **Purpose**: Distributed ingress management for applications
- **Configuration**: Environment-specific resource allocation
- **Load Balancer**: External Azure Load Balancer with environment-specific naming

## Installation

### 1. Control-Plane Cluster

The nginx ingress controller is automatically installed on the control-plane cluster when you deploy the platform. The configuration is defined in:

- **ApplicationSet**: `gitops/bootstrap/control-plane/addons/oss/addons-nginx-ingress-appset.yaml`
- **Default Values**: `gitops/environments/default/addons/ingress-nginx/values.yaml`
- **Control-Plane Values**: `gitops/environments/control-plane/addons/ingress-nginx/values.yaml`

### 2. Workload Clusters

To enable nginx ingress on workload clusters, you need to:

1. **Add cluster labels** to enable the addon:
   ```yaml
   apiVersion: v1
   kind: Cluster
   metadata:
     name: your-workload-cluster
     labels:
       enable_nginx_ingress: "true"
       environment: "dev"  # or "prod"
       nginx_ingress_chart_version: "4.7.1"
   ```

2. **Create environment-specific values** (optional):
   - `gitops/environments/dev/addons/ingress-nginx/values.yaml`
   - `gitops/environments/prod/addons/ingress-nginx/values.yaml`
   - `gitops/environments/clusters/{cluster-name}/addons/ingress-nginx/values.yaml`

## Configuration

### Default Configuration

The default configuration includes:

- **Azure Load Balancer Integration**: Configured for Azure CNI and Load Balancer
- **Security**: Non-root containers, security contexts, and RBAC
- **Monitoring**: Prometheus metrics enabled
- **Autoscaling**: Horizontal Pod Autoscaler configured
- **High Availability**: Pod Disruption Budget enabled

### Environment-Specific Configurations

#### Control-Plane
- **Replicas**: 2 (minimum)
- **Resources**: Higher allocation (200m-500m CPU, 256Mi-512Mi memory)
- **Autoscaling**: 2-10 replicas
- **Load Balancer**: Named "control-plane-ingress"

#### Development
- **Replicas**: 1 (minimum)
- **Resources**: Standard allocation (100m-200m CPU, 128Mi-256Mi memory)
- **Autoscaling**: 1-3 replicas
- **Load Balancer**: Named "dev-ingress"

#### Production
- **Replicas**: 3 (minimum)
- **Resources**: High allocation (300m-1000m CPU, 512Mi-1Gi memory)
- **Autoscaling**: 3-15 replicas
- **Load Balancer**: Named "prod-ingress" with session affinity

## Usage

### Creating Ingress Resources

Once the nginx ingress controller is installed, you can create ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

### Accessing the Load Balancer

After installation, you can get the external IP:

```bash
kubectl get service -n ingress-nginx ingress-nginx-controller
```

## Monitoring

### Metrics

The nginx ingress controller exposes Prometheus metrics on port 10254. You can scrape these metrics for monitoring:

- **Endpoint**: `/metrics`
- **Port**: `10254`
- **Annotations**: Already configured for Prometheus scraping

### Health Checks

The controller provides health check endpoints:

- **Readiness**: `/healthz`
- **Liveness**: `/healthz`

## Troubleshooting

### Common Issues

1. **Load Balancer not provisioned**:
   - Check Azure Load Balancer SKU (Standard required)
   - Verify network configuration
   - Check service annotations

2. **Ingress not working**:
   - Verify ingress class annotation
   - Check backend service availability
   - Review nginx ingress controller logs

3. **Performance issues**:
   - Monitor resource usage
   - Check autoscaling configuration
   - Review nginx configuration

### Logs

View controller logs:

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## Security Considerations

- **Network Policies**: Consider implementing network policies to restrict ingress traffic
- **TLS**: Always use TLS for production workloads
- **RBAC**: The controller runs with minimal required permissions
- **Pod Security**: Non-root containers with security contexts enabled

## References

- [GitOps Bridge Pattern](https://github.com/gitops-bridge-dev/gitops-bridge)
- [Nginx Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Azure Load Balancer Integration](https://cloud-provider-azure.sigs.k8s.io/topics/loadbalancer/)
- [Helm Chart Repository](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx) 