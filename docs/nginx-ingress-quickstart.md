# Nginx Ingress Quick Start Guide

This guide provides step-by-step instructions for enabling nginx ingress on workload clusters using the GitOps Bridge pattern.

## Prerequisites

- A Kubernetes cluster with ArgoCD installed
- GitOps Bridge pattern already configured
- Access to the cluster for applying configurations

## Quick Start

### 1. Enable Nginx Ingress on Control-Plane Cluster

The nginx ingress controller is automatically installed on the control-plane cluster. To verify:

```bash
# Check if the ApplicationSet exists
kubectl get applicationset -n argocd addons-nginx-ingress

# Check if the application is deployed
kubectl get application -n argocd addon-control-plane-ingress-nginx

# Check if the nginx ingress controller is running
kubectl get pods -n ingress-nginx
```

### 2. Enable Nginx Ingress on Workload Cluster

To enable nginx ingress on a workload cluster, you need to add the appropriate labels to the cluster resource:

```yaml
apiVersion: v1
kind: Cluster
metadata:
  name: your-workload-cluster
  labels:
    enable_nginx_ingress: "true"
    environment: "dev"  # or "prod"
    nginx_ingress_chart_version: "4.7.1"
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
kubectl get application -n argocd | grep nginx

# Check the application status
kubectl describe application addon-your-workload-cluster-ingress-nginx -n argocd

# Check if nginx ingress controller is running
kubectl get pods -n ingress-nginx
```

### 5. Get the Load Balancer IP

```bash
# Get the external IP of the nginx ingress controller
kubectl get service -n ingress-nginx ingress-nginx-controller

# The EXTERNAL-IP column shows the public IP address
```

## Customization

### Environment-Specific Configuration

You can customize the nginx ingress configuration for different environments:

1. **Development Environment**:
   ```bash
   # Edit the dev environment values
   kubectl edit configmap -n argocd addon-your-workload-cluster-ingress-nginx
   ```

2. **Production Environment**:
   ```bash
   # Edit the prod environment values
   kubectl edit configmap -n argocd addon-your-workload-cluster-ingress-nginx
   ```

### Cluster-Specific Configuration

For cluster-specific customization, create a values file at:
```
gitops/environments/clusters/{cluster-name}/addons/ingress-nginx/values.yaml
```

## Testing

### 1. Create a Test Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test-service
  namespace: default
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 2. Create an Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test-service
            port:
              number: 80
```

### 3. Test the Ingress

```bash
# Apply the test resources
kubectl apply -f test-app.yaml
kubectl apply -f test-ingress.yaml

# Get the load balancer IP
EXTERNAL_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test the ingress (replace with your actual domain)
curl -H "Host: test.example.com" http://$EXTERNAL_IP
```

## Troubleshooting

### Common Issues

1. **Application not syncing**:
   ```bash
   # Check application status
   kubectl describe application addon-your-workload-cluster-ingress-nginx -n argocd
   
   # Check application logs
   kubectl logs -n argocd deployment/argocd-application-controller
   ```

2. **Load Balancer not provisioned**:
   ```bash
   # Check service status
   kubectl describe service ingress-nginx-controller -n ingress-nginx
   
   # Check events
   kubectl get events -n ingress-nginx
   ```

3. **Ingress not working**:
   ```bash
   # Check nginx ingress controller logs
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   
   # Check ingress status
   kubectl describe ingress nginx-test-ingress
   ```

### Useful Commands

```bash
# Check all nginx ingress resources
kubectl get all -n ingress-nginx

# Check ingress controller configuration
kubectl get configmap -n ingress-nginx nginx-configuration -o yaml

# Check ingress rules
kubectl get ingress --all-namespaces

# Check service endpoints
kubectl get endpoints --all-namespaces
```

## Next Steps

- [Read the full documentation](nginx-ingress-gitops-bridge.md)
- [Configure TLS certificates](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
- [Set up monitoring](https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/)
- [Configure rate limiting](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#rate-limiting) 