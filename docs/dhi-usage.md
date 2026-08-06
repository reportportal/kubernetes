# Docker Hardened Images (DHI) Usage

This guide explains how to run the ReportPortal Helm chart dependencies **PostgreSQL** and **RabbitMQ** with [Docker Hardened Images](https://www.docker.com/products/hardened-images/) from the `dhi.io` registry.

The chart uses [CloudPirates](https://github.com/CloudPirates-io/helm-charts) subcharts for these dependencies. DHI images differ from Docker Official Images (entrypoints, UIDs, and data paths), so a few values overrides are required.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step 1: Authenticate and create an ImagePullSecret](#step-1-authenticate-and-create-an-imagepullsecret)
- [Step 2: Reference the secret in Helm values](#step-2-reference-the-secret-in-helm-values)
- [Step 3: Configure PostgreSQL for DHI](#step-3-configure-postgresql-for-dhi)
- [Step 4: Configure RabbitMQ for DHI](#step-4-configure-rabbitmq-for-dhi)
- [Complete example overlay](#complete-example-overlay)
- [Install or upgrade](#install-or-upgrade)
- [Verify](#verify)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Overview

| Component | Default image | DHI image |
|-----------|---------------|-----------|
| PostgreSQL | `postgres` (chart default tag) | [`dhi.io/postgres`](https://hub.docker.com/hardened-images/catalog/dhi/postgres) |
| RabbitMQ | `rabbitmq` (chart default tag) | [`dhi.io/rabbitmq`](https://hub.docker.com/hardened-images/catalog/dhi/rabbitmq/guides) |

Pick current tags from the DHI catalog when you deploy; this guide does not pin versions.

Important differences when switching to DHI:

- Images are pulled from `dhi.io` and require registry authentication.
- PostgreSQL DHI runs as UID/GID **70** (CloudPirates default is `999`).
- RabbitMQ DHI runs as UID/GID **65532** (CloudPirates default is `999`).
- PostgreSQL may need `image.useHardenedImage: true` and empty `args: []` so the subchart uses hardened-compatible data paths and startup.
- RabbitMQ DHI does not ship a `-management` tag the same way as Docker Official Images; enable plugins via `rabbitmq.additionalPlugins` (already required by ReportPortal).

OpenSearch and MinIO are unchanged by this guide.

---

## Prerequisites

- Kubernetes cluster and Helm 3.4+
- ReportPortal chart with CloudPirates PostgreSQL and RabbitMQ dependencies
- Access to Docker Hardened Images (`dhi.io`) for your organization
- `kubectl` access to the target namespace

---

## Step 1: Authenticate and create an ImagePullSecret

Log in to the DHI registry (credentials come from your Docker Hardened Images subscription):

```bash
docker login dhi.io
```

Create a Kubernetes pull secret in the namespace where ReportPortal will run:

```bash
kubectl create namespace reportportal --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry dhi-registry \
  --namespace reportportal \
  --docker-server=dhi.io \
  --docker-username='<your-username>' \
  --docker-password='<your-password-or-token>' \
  --docker-email='<your-email>'
```

Use a unique secret name if `dhi-registry` is already taken.

---

## Step 2: Reference the secret in Helm values

Set `global.imagePullSecrets` so ReportPortal pods and the CloudPirates subcharts can pull from `dhi.io`:

```yaml
global:
  imagePullSecrets:
    - name: dhi-registry
```

Helm shares `global.*` with subcharts, so PostgreSQL and RabbitMQ pick up the same pull secret.

---

## Step 3: Configure PostgreSQL for DHI

Override the PostgreSQL dependency image and security context. Keep your existing `auth` and `service` settings (or chart defaults / YAML anchors).

```yaml
postgresql:
  install: true
  image:
    registry: dhi.io
    repository: postgres
    ## Choose a current tag from the DHI catalog
    tag: "<tag>"
    ## Required for hardened images so the CloudPirates subchart selects
    ## the correct data directory layout
    useHardenedImage: true
  ## DHI images handle startup differently; disable default chart args
  args: []
  ## DHI postgres user is UID/GID 70 (subchart default is 999)
  containerSecurityContext:
    runAsUser: 70
    runAsGroup: 70
    runAsNonRoot: true
  podSecurityContext:
    fsGroup: 70
```

Catalog: [dhi.io/postgres](https://hub.docker.com/hardened-images/catalog/dhi/postgres).

---

## Step 4: Configure RabbitMQ for DHI

Override the RabbitMQ image and security context. Keep ReportPortal-required plugins and the `queue_master_locator` permit.

```yaml
rabbitmq:
  install: true
  image:
    registry: dhi.io
    repository: rabbitmq
    ## Choose a current tag from the DHI catalog
    tag: "<tag>"
  ## DHI rabbitmq user is UID/GID 65532 (subchart default is 999)
  containerSecurityContext:
    runAsUser: 65532
    runAsGroup: 65532
    runAsNonRoot: true
  podSecurityContext:
    fsGroup: 65532
  auth:
    enabled: true
  additionalPlugins:
    - rabbitmq_management
    - rabbitmq_consistent_hash_exchange
    - rabbitmq_shovel
    - rabbitmq_shovel_management
  config:
    extraConfiguration: |
      deprecated_features.permit.queue_master_locator = true
```

Catalog / guides: [dhi.io/rabbitmq](https://hub.docker.com/hardened-images/catalog/dhi/rabbitmq/guides).

> **Note:** DHI RabbitMQ uses `rabbitmq-server` as the entrypoint (not `docker-entrypoint.sh`). Prefer runtime tags from the catalog; avoid assuming Docker Official `-management` tag names.

---

## Complete example overlay

Save as `dhi-values.yaml`. Replace `<tag>` with a current tag from the [PostgreSQL](https://hub.docker.com/hardened-images/catalog/dhi/postgres) and [RabbitMQ](https://hub.docker.com/hardened-images/catalog/dhi/rabbitmq/guides) catalogs:

```yaml
global:
  imagePullSecrets:
    - name: dhi-registry

postgresql:
  install: true
  image:
    registry: dhi.io
    repository: postgres
    tag: "<tag>"
    useHardenedImage: true
  args: []
  containerSecurityContext:
    runAsUser: 70
    runAsGroup: 70
    runAsNonRoot: true
  podSecurityContext:
    fsGroup: 70

rabbitmq:
  install: true
  image:
    registry: dhi.io
    repository: rabbitmq
    tag: "<tag>"
  containerSecurityContext:
    runAsUser: 65532
    runAsGroup: 65532
    runAsNonRoot: true
  podSecurityContext:
    fsGroup: 65532
  additionalPlugins:
    - rabbitmq_management
    - rabbitmq_consistent_hash_exchange
    - rabbitmq_shovel
    - rabbitmq_shovel_management
  config:
    extraConfiguration: |
      deprecated_features.permit.queue_master_locator = true
```

---

## Install or upgrade

```bash
helm upgrade --install reportportal ./reportportal \
  --namespace reportportal \
  --create-namespace \
  -f dhi-values.yaml \
  --set uat.superadminInitPasswd.password='<strong-password>'
```

If you already have a values file for storage, ingress, or other settings, pass multiple `-f` flags; later files override earlier ones.

---

## Verify

```bash
# Images should reference dhi.io
kubectl get pods -n reportportal -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# PostgreSQL and RabbitMQ should become Ready
kubectl get pods -n reportportal -l 'app.kubernetes.io/name in (postgresql,postgres,rabbitmq)'

# Optional: confirm pull secret is attached
kubectl get pod -n reportportal -o yaml | grep -A2 imagePullSecrets
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ImagePullBackOff` / `401 Unauthorized` from `dhi.io` | Missing or wrong pull secret | Recreate the secret; ensure `global.imagePullSecrets` lists it |
| PostgreSQL CrashLoop: permission denied on data dir | UID/GID mismatch | Set `runAsUser` / `runAsGroup` / `fsGroup` to **70** |
| PostgreSQL fails on data path / init | Hardened layout not selected | Set `image.useHardenedImage: true` and `args: []` |
| RabbitMQ CrashLoop: permission denied | UID/GID mismatch | Set security contexts to **65532** |
| ReportPortal API cannot reach management API | Management plugin not enabled | Include `rabbitmq_management` (and shovel plugins) in `additionalPlugins` |
| Cannot `kubectl exec` / no shell in pod | Expected for DHI runtime images | Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) or a debug sidecar; DHI runtime images omit a shell |

Migrating an existing PVC created with UID `999` to DHI UIDs may require fixing volume ownership or recreating the volume. Prefer applying DHI settings on a fresh install when possible.

---

## References

- [DHI PostgreSQL catalog](https://hub.docker.com/hardened-images/catalog/dhi/postgres)
- [DHI RabbitMQ guides](https://hub.docker.com/hardened-images/catalog/dhi/rabbitmq/guides)
- [Parameters reference](parameters-reference.md)
- ReportPortal chart values: `reportportal/values.yaml` (`postgresql.*`, `rabbitmq.*`, `global.imagePullSecrets`)
