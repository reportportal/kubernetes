# Gateway API Deployment Guide for ReportPortal

This guide provides comprehensive instructions for deploying ReportPortal using the Kubernetes Gateway API, the modern replacement for Ingress.

## Table of Contents

- [Overview](#overview)
- [Why Gateway API?](#why-gateway-api)
- [Prerequisites](#prerequisites)
- [Gateway API Concepts](#gateway-api-concepts)
- [Deployment Steps](#deployment-steps)
- [TLS Configuration](#tls-configuration)
  - [Using Your Own Certificate](#using-your-own-certificate)
  - [Using Let's Encrypt with Cert-Manager](#using-lets-encrypt-with-cert-manager)
- [Configuration Examples](#configuration-examples)
- [Gateway Controller: Envoy Gateway](#gateway-controller-envoy-gateway)
- [Troubleshooting](#troubleshooting)
- [Migration from Ingress](#migration-from-ingress)

## Overview

Gateway API is the next-generation Kubernetes API for managing external access to services. It provides more expressive, extensible, and role-oriented interfaces compared to the legacy Ingress API.

The latest version ([v1.4.1](https://github.com/kubernetes-sigs/gateway-api)) includes GA support for:
- `v1.GatewayClass`
- `v1.Gateway`
- `v1.HTTPRoute`
- `v1.GRPCRoute`
- `v1.BackendTLSPolicy`

## Why Gateway API?

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| Role separation | Limited | Gateway/Route split |
| Protocol support | HTTP/HTTPS | HTTP, HTTPS, TCP, UDP, gRPC |
| Header-based routing | Controller-specific | Native support |
| Traffic splitting | Limited | Native support |
| Cross-namespace | Limited | ReferenceGrant |
| Extensibility | Annotations | Policy attachments |

## Prerequisites

### 1. Kubernetes Cluster
- Kubernetes 1.26+ (Gateway API v1.4.1)
- kubectl configured with cluster access

### 2. Gateway API CRDs

Install the Gateway API Custom Resource Definitions:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
```

Verify installation:

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

Expected output:
```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
```

### 3. Gateway Controller

You need a Gateway controller implementation. See [Gateway Controller Options](#gateway-controller-options) for installation instructions.

## Gateway API Concepts

### Key Resources

1. **GatewayClass**: Defines the controller implementation (similar to IngressClass)
2. **Gateway**: Represents a load balancer with listeners
3. **HTTPRoute**: Defines routing rules to backend services

### ReportPortal Gateway API Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Gateway                              │
│  (LoadBalancer with HTTP/HTTPS listeners)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        HTTPRoute                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │   /     │ │  /ui    │ │  /uat   │ │  /api   │           │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘           │
└───────┼──────────┼──────────┼──────────┼────────────────────┘
        ▼          ▼          ▼          ▼
   ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │ Index  │ │   UI   │ │  UAT   │ │  API   │
   │Service │ │Service │ │Service │ │Service │
   └────────┘ └────────┘ └────────┘ └────────┘
```

## Deployment Steps

### Step 1: Create Values File

Create a `values-gateway-api.yaml` file:

```yaml
# Disable legacy Ingress
ingress:
  enable: false

# Enable Gateway API
gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  
  # Reference an existing Gateway
  gatewayRef:
    name: my-gateway
    namespace: gateway-system  # optional
  
  # Or create a new Gateway
  gateway:
    create: true
    className: envoy-gateway
```

### Step 2: Deploy ReportPortal

```bash
# Add the Helm repository
helm repo add reportportal https://reportportal.github.io/kubernetes
helm repo update

# Deploy ReportPortal with Gateway API
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --values values-gateway-api.yaml \
  --set uat.superadminInitPasswd.password="YourSecurePassword"
```

### Step 3: Verify Deployment

```bash
# Check Gateway status
kubectl get gateway -n reportportal

# Check HTTPRoute status
kubectl get httproute -n reportportal

# Check if routes are attached
kubectl describe httproute -n reportportal
```

## TLS Configuration

### Using Your Own Certificate

#### Option 1: Create TLS Secret and Reference in Gateway

1. Create a TLS secret from your certificate files:

```bash
kubectl create secret tls reportportal-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n reportportal
```

2. Configure Gateway with TLS:

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  gateway:
    create: true
    className: envoy-gateway
    tls:
      enable: true
      secretName: reportportal-tls
```

#### Option 2: Use Custom Certificate References

For advanced scenarios with multiple certificates:

```yaml
gatewayAPI:
  enable: true
  hostnames:
    - reportportal.example.com
    - rp.example.com
  gateway:
    create: true
    className: envoy-gateway
    tls:
      enable: true
      certificateRefs:
        - kind: Secret
          name: reportportal-tls
          namespace: reportportal
```

#### Option 3: Custom Gateway Listeners

For full control over Gateway configuration:

```yaml
gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  gateway:
    create: true
    className: envoy-gateway
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: reportportal.example.com
        allowedRoutes:
          namespaces:
            from: Same
      - name: https
        protocol: HTTPS
        port: 443
        hostname: reportportal.example.com
        tls:
          mode: Terminate
          certificateRefs:
            - kind: Secret
              name: reportportal-tls
        allowedRoutes:
          namespaces:
            from: Same
```

### Using Let's Encrypt with Cert-Manager

Cert-Manager supports Gateway API natively for automatic certificate management.

#### Step 1: Install Cert-Manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
```

Verify installation:

```bash
kubectl -n cert-manager get pods
```

#### Step 2: Create ClusterIssuer for Let's Encrypt

Create a file called `letsencrypt-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: reportportal-gateway
                namespace: reportportal
                kind: Gateway
```

Apply the issuer:

```bash
kubectl apply -f letsencrypt-issuer.yaml
```

#### Step 3: Create Certificate Resource

Create a file called `certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: reportportal-tls
  namespace: reportportal
spec:
  secretName: reportportal-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - reportportal.example.com
```

Apply the certificate:

```bash
kubectl apply -f certificate.yaml
```

#### Step 4: Deploy ReportPortal with TLS

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  gateway:
    create: true
    className: envoy-gateway
    tls:
      enable: true
      secretName: reportportal-tls  # Managed by cert-manager
```

#### Step 5: Verify Certificate

```bash
# Check certificate status
kubectl get certificate -n reportportal

# Check certificate details
kubectl describe certificate reportportal-tls -n reportportal

# Check the secret was created
kubectl get secret reportportal-tls -n reportportal
```

### Using DNS-01 Challenge (Wildcard Certificates)

For wildcard certificates or when HTTP-01 is not available:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-dns-account-key
    solvers:
      - dns01:
          cloudflare:
            email: your-cloudflare-email@example.com
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

## Configuration Examples

### Example 1: Basic HTTP Deployment

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  gatewayRef:
    name: shared-gateway
    namespace: gateway-system
```

### Example 2: HTTPS with Custom Certificate

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  gateway:
    create: true
    className: envoy-gateway
    annotations:
      external-dns.alpha.kubernetes.io/hostname: reportportal.example.com
    tls:
      enable: true
      mode: Terminate
      secretName: reportportal-tls
```

### Example 3: With Base Path

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: example.com
  path: /reportportal
  gatewayRef:
    name: shared-gateway
```

This creates routes:
- `/reportportal` → Index service
- `/reportportal/ui` → UI service
- `/reportportal/uat` → UAT service
- `/reportportal/api` → API service

### Example 4: Multiple Hostnames

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames:
    - reportportal.example.com
    - rp.example.com
    - testing.example.com
  gateway:
    create: true
    className: envoy-gateway
    tls:
      enable: true
      secretName: reportportal-tls
```

### Example 5: Reference Existing Gateway in Different Namespace

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  gatewayRef:
    name: central-gateway
    namespace: gateway-infra
    sectionName: https  # Specific listener name
```

> **Note**: You may need a `ReferenceGrant` to allow cross-namespace references.

### Example 6: Advanced with HTTPRoute Annotations

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com
  httpRoute:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: reportportal.example.com
      external-dns.alpha.kubernetes.io/ttl: "60"
  gateway:
    create: true
    className: envoy-gateway
    tls:
      enable: true
      secretName: reportportal-tls
```

## Gateway Controller: Envoy Gateway

This guide uses [Envoy Gateway](https://gateway.envoyproxy.io/) - a lightweight, Envoy-based Gateway controller.

### Install Envoy Gateway

```bash
# Install Envoy Gateway
# Note: Use --skip-crds if you already installed Gateway API CRDs separately
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.0 \
  -n envoy-gateway-system \
  --create-namespace \
  --skip-crds

# Wait for Envoy Gateway to be ready
kubectl wait --for=condition=Available deployment/envoy-gateway -n envoy-gateway-system --timeout=120s

# Create GatewayClass
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF

# Verify GatewayClass is accepted
kubectl get gatewayclass envoy-gateway
```

### Use with ReportPortal

```yaml
gatewayAPI:
  gateway:
    className: envoy-gateway
```

### Other Gateway Controllers

ReportPortal Gateway API support is compatible with any Gateway API implementation. 
For other controllers, consult their documentation:

- [Istio](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [Cilium](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [GKE Gateway Controller](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api)

## Troubleshooting

### Common Issues

#### 1. Gateway Not Programmed

```bash
# Check Gateway status
kubectl get gateway -n reportportal -o yaml

# Check GatewayClass exists and is accepted
kubectl get gatewayclass

# Check controller logs
kubectl logs -n <controller-namespace> deployment/<controller-name>
```

#### 2. HTTPRoute Not Attached

```bash
# Check HTTPRoute status
kubectl describe httproute -n reportportal

# Verify parentRefs match Gateway
kubectl get gateway -n reportportal -o jsonpath='{.metadata.name}'
```

#### 3. TLS Certificate Issues

```bash
# Check certificate status (if using cert-manager)
kubectl describe certificate -n reportportal

# Check secret exists
kubectl get secret -n reportportal | grep tls

# Verify secret has correct keys
kubectl get secret reportportal-tls -n reportportal -o jsonpath='{.data}' | jq 'keys'
```

#### 4. Services Not Reachable

```bash
# Check services exist
kubectl get svc -n reportportal

# Test from within cluster
kubectl run curl --rm -it --image=curlimages/curl -- \
  curl -H "Host: reportportal.example.com" http://<gateway-ip>/api/health
```

### Debugging Commands

```bash
# Get Gateway address
kubectl get gateway -n reportportal -o jsonpath='{.status.addresses[0].value}'

# Check attached routes
kubectl get gateway -n reportportal -o jsonpath='{.status.listeners[*].attachedRoutes}'

# View HTTPRoute conditions
kubectl get httproute -n reportportal -o jsonpath='{.status.parents[*].conditions}'

# Check Envoy config (for Envoy Gateway)
kubectl port-forward -n envoy-gateway-system deploy/envoy-gateway 19000:19000
curl localhost:19000/config_dump
```

## Migration from Ingress

### Step 1: Deploy Gateway API Resources

Deploy ReportPortal with both Ingress and Gateway API temporarily:

```yaml
# Keep Ingress enabled during migration
ingress:
  enable: true
  class: nginx
  hosts: reportportal.example.com

# Enable Gateway API in parallel
gatewayAPI:
  enable: true
  hostnames: reportportal-new.example.com  # Use different hostname initially
  gateway:
    create: true
    className: envoy-gateway
```

### Step 2: Test Gateway API

Verify Gateway API routing works:

```bash
curl -H "Host: reportportal-new.example.com" http://<gateway-ip>/api/health
```

### Step 3: Switch DNS

Update DNS to point to Gateway instead of Ingress:

```bash
# Get Gateway IP
kubectl get gateway -n reportportal -o jsonpath='{.status.addresses[0].value}'
```

### Step 4: Disable Ingress

Once verified, disable Ingress:

```yaml
ingress:
  enable: false

gatewayAPI:
  enable: true
  hostnames: reportportal.example.com  # Original hostname
  gateway:
    create: true
    className: envoy-gateway
```

## Additional Resources

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Cert-Manager Gateway API Integration](https://cert-manager.io/docs/usage/gateway/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [ReportPortal Documentation](https://reportportal.io/docs)

## Support

For issues specific to ReportPortal Gateway API deployment:
- Check the [ReportPortal GitHub Issues](https://github.com/reportportal/kubernetes/issues)
- Review Gateway controller documentation
- Consult cert-manager documentation for TLS issues

