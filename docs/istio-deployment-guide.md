# Istio Ingress Gateway Deployment Guide for ReportPortal

This guide covers deploying ReportPortal behind an Istio Ingress Gateway using native
Istio `Gateway` and `VirtualService` resources — the recommended approach for clusters
that already run Istio as a service mesh.

## Table of Contents

- [Overview](#overview)
- [When to use this over Ingress / Gateway API](#when-to-use-this-over-ingress--gateway-api)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [TLS Configuration](#tls-configuration)
- [Configuration Examples](#configuration-examples)
- [Attaching to an Existing Gateway](#attaching-to-an-existing-gateway)
- [Gateway Selector](#gateway-selector)
- [Troubleshooting](#troubleshooting)

---

## Overview

When `istio.enable: true` is set, the chart renders two additional resources:

| Resource | Kind | Purpose |
|----------|------|---------|
| `<release>-istio-gateway` | `networking.istio.io/v1beta1 Gateway` | Configures the Istio ingress gateway listeners (HTTP/HTTPS) |
| `<release>-virtual-service` | `networking.istio.io/v1beta1 VirtualService` | Routes `/api`, `/uat`, `/ui`, and `/` to the correct backend services |

The existing `Ingress` and Gateway API resources are independent — disable them to avoid
routing conflicts:

```bash
--set ingress.enable=false
--set gatewayAPI.enable=false
```

---

## When to use this over Ingress / Gateway API

| Scenario | Recommended approach |
|----------|---------------------|
| Cluster already runs Istio for mTLS / observability | **This guide** (`istio.enable`) |
| No service mesh, standard ingress controller | `ingress.enable` |
| No service mesh, modern cluster-native approach | `gatewayAPI.enable` |

---

## Prerequisites

1. **Kubernetes 1.26+** with Helm 3.4+
2. **Istio installed** in the cluster (`istiod` + an ingress gateway deployment):

```bash
# Install Istio via Helm (if not already present)
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm install istio-base   istio/base    -n istio-system --create-namespace
helm install istiod       istio/istiod  -n istio-system --wait
helm install istio-ingress istio/gateway -n istio-ingress --create-namespace --wait
```

Verify the environment:

```bash
kubectl get deployments -n istio-system    # istiod: 1/1
kubectl get deployments -n istio-ingress   # istio-ingress: 1/1
kubectl get svc -n istio-ingress           # LoadBalancer with an EXTERNAL-IP
```

3. (Optional) **Sidecar injection** on the ReportPortal namespace for full mTLS:

```bash
kubectl label namespace <your-namespace> istio-injection=enabled
```

---

## Architecture

```
                          ┌───────────────────────────────────────┐
  External traffic  ─────►│  Istio IngressGateway (LoadBalancer)  │
                          └─────────────────┬─────────────────────┘
                                            │  selector: istio=ingressgateway
                          ┌─────────────────▼─────────────────────┐
                          │          Istio Gateway CR              │
                          │   (HTTP :80  ·  HTTPS :443 optional)   │
                          └─────────────────┬─────────────────────┘
                                            │
                          ┌─────────────────▼─────────────────────┐
                          │         VirtualService                 │
                          │  /api  → reportportal-api   :8585      │
                          │  /uat  → reportportal-uat   :9999      │
                          │  /ui   → reportportal-ui    :8080      │
                          │  /     → reportportal-index :8080      │
                          └────────────────────────────────────────┘
```

Route order matters in Istio VirtualServices — the chart always places `/api`, `/uat`,
and `/ui` before the root `/` catch-all.

---

## Quick Start

```bash
helm install my-release reportportal/reportportal \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set istio.enable=true \
  --set istio.hosts="reportportal.example.com" \
  --set ingress.enable=false \
  --set gatewayAPI.enable=false
```

After install, get the ingress IP and verify:

```bash
export INGRESS_HOST=$(kubectl get svc -n istio-ingress \
  -l app=istio-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

curl -H "Host: reportportal.example.com" http://$INGRESS_HOST/ui
```

---

## TLS Configuration

### Using an existing TLS secret

> **Important:** The TLS secret must exist in the **same namespace as the Istio
> ingress gateway pod** (typically `istio-ingress`), not the application namespace.
> This is an Istio requirement — the gateway proxy reads the secret directly.

```bash
# Create the secret in the gateway namespace
kubectl create secret tls reportportal-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n istio-ingress
```

Enable TLS in the chart:

```yaml
istio:
  enable: true
  hosts: reportportal.example.com
  ingress.enable: false
  gatewayAPI.enable: false
  gateway:
    create: true
    tls:
      enable: true
      mode: SIMPLE
      credentialName: reportportal-tls   # secret name in istio-ingress namespace
```

Or via `--set`:

```bash
helm install my-release reportportal/reportportal \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set istio.enable=true \
  --set istio.hosts="reportportal.example.com" \
  --set istio.gateway.tls.enable=true \
  --set istio.gateway.tls.credentialName=reportportal-tls \
  --set ingress.enable=false \
  --set gatewayAPI.enable=false
```

### TLS modes

| `istio.gateway.tls.mode` | Description |
|--------------------------|-------------|
| `SIMPLE` | Standard TLS termination (default) |
| `MUTUAL` | mTLS — client certificate required |
| `PASSTHROUGH` | TLS pass-through to the backend (set on port listener) |

---

## Configuration Examples

### Single hostname

```yaml
istio:
  enable: true
  hosts: reportportal.example.com
```

### Multiple hostnames

```yaml
istio:
  enable: true
  hosts:
    - reportportal.example.com
    - rp.example.com
```

### Wildcard host (match any)

```yaml
istio:
  enable: true
  hosts: "*"
```

### With a base path

Useful when ReportPortal shares a domain with other services:

```yaml
istio:
  enable: true
  hosts: example.com
  path: /reportportal
```

This creates routes for `/reportportal/api`, `/reportportal/uat`,
`/reportportal/ui`, and `/reportportal`.

### With VirtualService annotations

```yaml
istio:
  enable: true
  hosts: reportportal.example.com
  virtualService:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: reportportal.example.com
```

---

## Attaching to an Existing Gateway

Set `gateway.create: false` and point to a Gateway that already exists in your cluster:

```yaml
istio:
  enable: true
  hosts: reportportal.example.com
  gateway:
    create: false
    name: shared-gateway
    namespace: istio-ingress   # namespace of the existing Gateway
```

The VirtualService will reference it as `istio-ingress/shared-gateway`.
If `namespace` is omitted, only the name is used (same-namespace reference).

---

## Gateway Selector

The `istio.gateway.selector` field controls which Envoy proxy the Gateway resource
binds to. The default is:

```yaml
istio:
  gateway:
    selector:
      istio: ingressgateway
```

This matches the standard Istio ingress gateway deployment created by `istioctl install`.
If your ingress gateway was installed via the Helm `gateway` chart (as in the Quick
Start above), the pod label may differ. Check the actual labels:

```bash
kubectl get pods -n istio-ingress --show-labels
```

Common values:

| Installation method | Typical selector label |
|---------------------|------------------------|
| `istioctl install` (default profile) | `istio: ingressgateway` |
| Helm `istio/gateway` chart with name `istio-ingress` | `istio: ingress` |
| Custom deployment | Check pod labels |

Override at install time:

```bash
--set "istio.gateway.selector.istio=ingress"
```

---

## Troubleshooting

### 404 from the gateway

```bash
# 1. Confirm the Gateway is attached to the right proxy
kubectl get gateway <release>-istio-gateway -o yaml
# spec.selector must match the ingress gateway pod labels

# 2. Confirm VirtualService references the right gateway name
kubectl get virtualservice <release>-virtual-service -o yaml
# spec.gateways[0] must match the Gateway metadata.name

# 3. Check the ingress gateway proxy config
kubectl exec -n istio-ingress deploy/istio-ingress -- \
  pilot-agent request GET config_dump | grep -A5 "route_config"
```

### 503 Service Unavailable

```bash
# Check all ReportPortal pods are Ready
kubectl get pods -l app=reportportal

# Confirm services exist and ports match
kubectl get svc -l app=reportportal

# Check Envoy sidecar logs (if injection is enabled)
kubectl logs <pod> -c istio-proxy --tail=50
```

### TLS handshake failure

```bash
# Verify the secret exists in the gateway namespace (NOT the app namespace)
kubectl get secret reportportal-tls -n istio-ingress

# Check gateway status for certificate errors
kubectl describe gateway <release>-istio-gateway
```

### Gateway hosts mismatch with VirtualService

Both the `Gateway` and the `VirtualService` must list compatible hosts.
If the Gateway uses `"*"`, the VirtualService can use specific hostnames.
If the Gateway specifies `reportportal.example.com`, the VirtualService must
list the same hostname (or a subdomain). A mismatch produces 404s.

---

## Additional Resources

- [Istio Ingress Gateway documentation](https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/)
- [Istio TLS configuration](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/)
- [Install Istio via Helm](https://istio.io/latest/docs/setup/install/helm/)
- [Gateway API Deployment Guide](gateway-api-deployment-guide.md) — alternative without a service mesh
- [ReportPortal Documentation](https://reportportal.io/docs)
