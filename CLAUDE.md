# EPMRPP — Istio Ingress Integration (`feature/istio-ingress-integration`)

## Session starter prompt

> Paste this at the beginning of a new Claude session to resume with full context.

```
I'm working on EPMRPP ticket: adding native Istio ingress support to the
ReportPortal Helm chart (reportportal/kubernetes repo).

Setup is complete:
- Branch: feature/istio-ingress-integration (from develop)
- Local cluster: Docker Desktop with Istio 1.30.1 installed
  (istio-base + istiod in istio-system, istio-ingress gateway in istio-ingress namespace)

The work remaining is steps 3 and 4:
3. Create reportportal/templates/ingress/istio-gateway.yaml and
   istio-virtual-service.yaml with proper RPP routing.
4. Add an istio.enable conditional block to values.yaml.

Key facts about the chart (from reading the source):
- Four front-facing services: index (8080, /), ui (8080, /ui), uat (9999, /uat), api (8585, /api)
- Existing ingress resources are gated on ingress.enable and gatewayAPI.enable — the
  new Istio templates follow the same pattern with istio.enable
- The gateway.create toggle (from gateway.yaml) and the basePath/host string-or-list
  pattern (from gateway-http-route.yaml) should be reused in the new templates
- VirtualService routes must be ordered most-specific first: /api, /uat, /ui, then / last
- destination.host uses the short k8s service name (same namespace)

Please read reportportal/templates/ingress/ before writing anything so you have
the exact current Helm template style. Let's start with istio-gateway.yaml.
```

---


## Status

| Step | Description | Status |
|------|-------------|--------|
| 1 | Install Istio + Istio Ingress Gateway locally (Docker Desktop) | ✅ Done |
| 2 | Create branch `feature/istio-ingress-integration` from `develop` | ✅ Done |
| 3 | Add `istio-gateway.yaml` and `istio-virtual-service.yaml` | 🔲 Next |
| 4 | Implement `istio.enable` conditional in `values.yaml` | 🔲 Next |

### Step 1 — Local environment (completed)

Installed on Docker Desktop Kubernetes cluster:

```
istio-base   → istio-system    (chart: base-1.30.1)
istiod       → istio-system    (chart: istiod-1.30.1)
istio-ingress → istio-ingress  (chart: gateway-1.30.1)
```

The `istio-ingress` LoadBalancer service will resolve to `127.0.0.1` on Docker Desktop.

### Step 2 — Branch (completed)

Branch `feature/istio-ingress-integration` created from `develop` in
`reportportal/kubernetes`.

---

## Context

This document covers steps 3 and 4 of the Istio ingress integration task: adding
`istio-gateway.yaml` and `istio-virtual-service.yaml` to the Helm chart, and wiring
them up behind an `istio.enable` conditional in `values.yaml`.

The implementation follows the same opt-in pattern used by the CNPG backend work:
**existing defaults are never touched**; the Istio path is only activated when
explicitly configured.

---

## Repo layout (relevant paths)

```
reportportal/
├── templates/
│   └── ingress/
│       ├── gateway-ingress.yaml       ← existing: Kubernetes Ingress (nginx/alb/gce)
│       ├── gateway.yaml               ← existing: Kubernetes Gateway API
│       ├── gateway-http-route.yaml    ← existing: Kubernetes HTTPRoute
│       ├── gateway-secret.yaml        ← existing: TLS secret
│       ├── gcp-managed-cert.yaml      ← existing: GCP managed cert
│       ├── istio-gateway.yaml         ← NEW (this task)
│       └── istio-virtual-service.yaml ← NEW (this task)
└── values.yaml
```

---

## Service port reference

All four front-facing services expose a single ClusterIP port. These are the values
used in the `VirtualService` routing rules:

| Service          | k8s Service name suffix | Port |
|------------------|-------------------------|------|
| Index (root `/`) | `-index`                | 8080 |
| UI (`/ui`)       | `-ui`                   | 8080 |
| UAT/auth (`/uat`)| `-uat`                  | 9999 |
| API (`/api`)     | `-api`                  | 8585 |

All services default to `portName: headless`. The `VirtualService` routes by port
number (not name) since Istio resolves ClusterIP services directly.

---

## Existing `values.yaml` structure to mirror

The existing ingress controllers follow this pattern:

```yaml
# Kubernetes Ingress (nginx/alb/gce)
ingress:
  enable: true/false
  ...

# Kubernetes Gateway API
gatewayAPI:
  enable: false
  ...
```

### New block to add — `istio` section

Add at the end of the ingress-related sections, **after** `gatewayAPI:`:

```yaml
## @section Istio Ingress Gateway Configuration
## Enable when your cluster already runs Istio as a service mesh.
## This renders an Istio Gateway + VirtualService instead of a Kubernetes Ingress.
## Requires Istio to be installed (istiod + istio-ingressgateway).
##
istio:
  ## @param istio.enable Enable Istio Gateway and VirtualService resources
  ##
  enable: false

  ## @param istio.hosts Hostname(s) the Gateway and VirtualService will match
  ## Can be a single string or a list. Use "*" to match any host.
  ## Example:
  ##   hosts: reportportal.example.com
  ## or:
  ##   hosts:
  ##     - reportportal.example.com
  ##
  hosts: null

  ## @param istio.path Base path prefix for all routes (default: "")
  ## Example: "/reportportal" routes /reportportal/ui, /reportportal/api, etc.
  ##
  path: ""

  ## @param istio.gateway Istio Gateway resource configuration
  ##
  gateway:
    ## @param istio.gateway.create Create a Gateway resource (set false to attach to an existing one)
    ##
    create: true

    ## @param istio.gateway.name Override the Gateway name (defaults to <fullname>-istio-gateway)
    ##
    name: ""

    ## @param istio.gateway.namespace Namespace of an existing Gateway to attach to
    ## Only used when gateway.create=false
    ##
    namespace: ""

    ## @param istio.gateway.selector Istio ingress gateway pod selector labels
    ## Defaults to the standard istio-ingressgateway selector.
    ##
    selector:
      istio: ingressgateway

    ## @param istio.gateway.tls TLS configuration
    ##
    tls:
      ## @param istio.gateway.tls.enable Add an HTTPS listener on port 443
      ##
      enable: false

      ## @param istio.gateway.tls.mode Istio TLS mode: SIMPLE, MUTUAL, or PASSTHROUGH
      ##
      mode: SIMPLE

      ## @param istio.gateway.tls.credentialName Kubernetes Secret name holding the TLS cert/key
      ## Secret must exist in the same namespace as the Gateway.
      ##
      credentialName: ""

  ## @param istio.virtualService VirtualService configuration
  ##
  virtualService:
    ## @param istio.virtualService.annotations Annotations for the VirtualService
    ##
    annotations: {}
```

---

## `istio-gateway.yaml` — what to implement

File: `reportportal/templates/ingress/istio-gateway.yaml`

**Condition:** `{{- if and .Values.istio.enable .Values.istio.gateway.create }}`

### Spec logic

```
spec:
  selector:               ← .Values.istio.gateway.selector (default: istio: ingressgateway)
  servers:
    - port 80 (HTTP)
      hosts: <from values>
    - port 443 (HTTPS)    ← only when .Values.istio.gateway.tls.enable=true
      tls:
        mode: .Values.istio.gateway.tls.mode
        credentialName: .Values.istio.gateway.tls.credentialName
      hosts: <from values>
```

**Host handling:** `hosts` can be a string or a list (same pattern as `gatewayAPI.hostnames`
in `gateway.yaml`). Use `"*"` as the default when `hosts` is null.

**Naming:**
```
name: {{ .Values.istio.gateway.name | default (printf "%s-istio-gateway" $fullName) }}
```

---

## `istio-virtual-service.yaml` — what to implement

File: `reportportal/templates/ingress/istio-virtual-service.yaml`

**Condition:** `{{- if .Values.istio.enable }}`

### `gateways` reference

When `istio.gateway.create=true`, reference the gateway by name (same namespace).  
When `istio.gateway.create=false`, reference via `istio.gateway.namespace/name`.

```yaml
gateways:
  - {{ gatewayRef }}   # <namespace/>name
```

### `hosts` field

Mirror the Gateway hosts — same string/list handling.

### Route rules (the core of the work)

The four services must be routed in **specificity order** (most specific first).
Istio evaluates rules top-to-bottom; the root `/` catch-all must be last.

```
$basePath := trimSuffix "/" .Values.istio.path   (empty string if path is "/" or "")
```

| Priority | Match prefix          | Destination service | Port |
|----------|-----------------------|---------------------|------|
| 1        | `$basePath/api`       | `<fullname>-api`    | 8585 |
| 2        | `$basePath/uat`       | `<fullname>-uat`    | 9999 |
| 3        | `$basePath/ui`        | `<fullname>-ui`     | 8080 |
| 4        | `$basePath/` or `$basePath` | `<fullname>-index` | 8080 |

Istio VirtualService uses `http[].match[].uri.prefix` for path matching:

```yaml
http:
  - match:
      - uri:
          prefix: "/api"
    route:
      - destination:
          host: <fullname>-api
          port:
            number: 8585
  ...
```

**Note on `host` in `destination`:** In Istio, `host` is the Kubernetes Service name
(short name resolves within the same namespace). Use the full service name without
namespace suffix (e.g. `reportportal-api`), not a FQDN, unless the VirtualService
is in a different namespace than the services.

---

## Conditional rendering guard

Both files must be mutually exclusive with the existing ingress resources.
The recommended approach is a note in the values documentation, not a hard Helm
`fail` — users may run multiple ingress methods intentionally in some migration scenarios.

However, the existing `gateway-ingress.yaml` is already gated on `ingress.enable`,
`gateway.yaml` on `gatewayAPI.enable`, so as long as `istio.enable` is a separate
flag, there is no conflict by default.

---

## How to test locally

### ~~1. Install Istio via Helm~~ (already done)

Istio is installed on the Docker Desktop cluster. To verify the environment is still healthy at the start of a session:

```bash
kubectl get deployments -n istio-system   # istiod 1/1
kubectl get deployments -n istio-ingress  # istio-ingress 1/1
kubectl get svc -n istio-ingress          # LoadBalancer → 127.0.0.1
```

### 2. Render the chart templates (dry-run, no cluster needed)

```bash
helm template reportportal ./reportportal \
  --set istio.enable=true \
  --set istio.hosts="reportportal.example.com" \
  --set ingress.enable=false \
  --set gatewayAPI.enable=false \
  | grep -A50 "kind: Gateway\|kind: VirtualService"
```

Expected output: one `Gateway` and one `VirtualService`, no `Ingress` or `HTTPRoute`.

### 3. Lint

```bash
helm lint ./reportportal --set istio.enable=true --set istio.hosts="rp.example.com"
```

### 4. Deploy to local cluster with sidecar injection

```bash
kubectl label namespace default istio-injection=enabled

helm upgrade --install reportportal ./reportportal \
  --set istio.enable=true \
  --set istio.hosts="reportportal.example.com" \
  --set ingress.enable=false \
  --set gatewayAPI.enable=false \
  # ... plus your storage/db values
```

### 5. Verify ingress IP and test routing

```bash
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H "Host: reportportal.example.com" http://$INGRESS_HOST/
curl -H "Host: reportportal.example.com" http://$INGRESS_HOST/ui
curl -H "Host: reportportal.example.com" http://$INGRESS_HOST/api
curl -H "Host: reportportal.example.com" http://$INGRESS_HOST/uat
```

---

## Common pitfalls

| Pitfall | Notes |
|---------|-------|
| Gateway in wrong namespace | The `istio-ingressgateway` pod must be able to read the `Gateway` resource. Default setup (gateway in `istio-ingress`, Gateway CR in `default`) works fine — Istio watches all namespaces. |
| Namespace missing `istio-injection` label | Sidecar won't be injected; east-west mTLS won't work but ingress still functions. |
| `credentialName` secret not in gateway namespace | TLS secret must be in the **same namespace as the Gateway pod** (`istio-ingress`), not the app namespace. |
| Route order in VirtualService | Istio uses first-match; always put `/api`, `/uat`, `/ui` before the root `/` catch-all. |
| `hosts: "*"` in Gateway vs VirtualService | Both must agree. If Gateway uses `"*"`, VirtualService can use specific hostnames or `"*"`. Mismatch → 404. |

---

## Related files

- `reportportal/templates/ingress/gateway-ingress.yaml` — existing Ingress implementation to
  use as a structural reference for host/path handling patterns.
- `reportportal/templates/ingress/gateway.yaml` — existing Gateway API implementation;
  mirrors the `gateway.create` toggle pattern to reuse here.
- `reportportal/templates/ingress/gateway-http-route.yaml` — existing HTTPRoute; the
  route priority and basePath logic is directly portable to the VirtualService.
- Istio docs: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/
- Helm install guide: https://istio.io/latest/docs/setup/install/helm/
