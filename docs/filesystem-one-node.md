# Filesystem Storage on a Single-Node Cluster

This guide explains how to run ReportPortal with **filesystem storage** on a Kubernetes cluster using a PersistentVolumeClaim backed by local or shared storage.

All ReportPortal services — `api`, `uat`, `jobs`, and `analyzer` — share a **single PVC**. The storage backend must therefore support the `ReadWriteMany` access mode when pods are spread across multiple nodes, or `ReadWriteOnce` on a single-node cluster where all pods co-locate. See [storageclass.info/drivers](https://storageclass.info/drivers) for a full list of CSI drivers and their supported access modes.

For production multi-node clusters with shared storage (EFS, NFS, Filestore), see [S3 and Filesystem Storage on EKS](s3-storage-eks.md).

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Option A: local-path (Recommended)](#option-a-local-path-recommended)
- [Option B: Shared Volume via CSI Driver](#option-b-shared-volume-via-csi-driver)
- [Install ReportPortal](#install-reportportal)
- [Verify Storage](#verify-storage)
- [Access ReportPortal](#access-reportportal)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)

---

## Overview

ReportPortal supports three storage backends:

| Type | Best for |
|---|---|
| `minio` | Chart default; bundled S3-compatible storage |
| `s3` | Production cloud object storage |
| `filesystem` | Shared directory on a PersistentVolume |

Filesystem storage avoids running MinIO and stores attachments on a single shared PVC. All services — `api`, `uat`, `jobs`, and `analyzer` — mount the **same PVC** at `/data/storage`. The analyzer writes exclusively to its own **`/data/storage/analyzer/`** subdirectory so it never contends with per-project attachment directories created by the other services.

**How it works:**

```
                  ┌─────────────────────────────────────────┐
                  │              shared PVC                 │
api, uat, jobs ──▶│  /data/storage/                         │  attachments, per-project uploads
analyzer       ──▶│  /data/storage/analyzer/                │  ML models, log-analysis indices
                  └─────────────────────────────────────────┘
                                    │
                             PersistentVolume
                                    │
                               node disk / CSI
```

---

## Prerequisites

- A running single-node cluster (Rancher Desktop, Minikube, or k3s)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [Helm](https://helm.sh/docs/intro/install/)
- A default StorageClass (Rancher Desktop ships with `local-path`)

Check your StorageClass:

```bash
kubectl get storageclass
```

Example output on Rancher Desktop:

```
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```

---

## Option A: local-path (Recommended)

Use this when your cluster has a default **ReadWriteOnce** provisioner such as `local-path`. No manual directory setup is required.

The chart defaults to **ReadWriteMany**, which `local-path` does not support. Override `accessModes` to **ReadWriteOnce**. On a single node, all ReportPortal pods schedule on the same node and can share that volume.

Create `values-fs.yaml`:

```yaml
minio:
  install: false

storage:
  type: filesystem
  volume:
    defaultPath: "/data/storage"
    capacity: 10Gi
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    volumeConfig:
      type: ""   # empty = dynamic provisioning by local-path
```

A ready-to-use example is in [`test/fs-values.yaml`](../test/fs-values.yaml) in this repository.

---

## Option B: Shared Volume via CSI Driver

Use this when you need **ReadWriteMany** access — for example a multi-node cluster or any setup where pods may schedule on different nodes. Point `storageClassName` at a StorageClass backed by a CSI driver that supports `ReadWriteMany` file storage. Common choices:

| Driver | CSI provisioner |
|---|---|
| AWS EFS | `efs.csi.aws.com` |
| Google Filestore | `filestore.csi.storage.gke.io` |
| Azure File | `file.csi.azure.com` |
| NFS | `nfs.csi.k8s.io` |
| CephFS | `cephfs.csi.ceph.com` |

See [storageclass.info/drivers](https://storageclass.info/drivers) for a full catalogue filtered by access mode and capabilities.

```yaml
minio:
  install: false

storage:
  type: filesystem
  volume:
    defaultPath: "/data/storage"
    capacity: 10Gi
    storageClassName: efs-sc          # your ReadWriteMany StorageClass
    accessModes:
      - ReadWriteMany
    reclaimPolicy: Retain             # Retain (default) or Delete — see note below
    volumeConfig:
      type: ""                        # empty = dynamic provisioning by the StorageClass
```

> **`reclaimPolicy` note:** this setting applies only when the chart provisions a **static** PersistentVolume (`volumeConfig.type` is `local` or `csi`). It controls what happens to the PV after the PVC is deleted:
> - `Retain` (default) — the PV stays; you must reclaim it manually. Safe for data you want to keep across reinstalls.
> - `Delete` — the PV is removed with the PVC (behaviour depends on the CSI driver).
>
> For dynamic provisioning (`volumeConfig.type: ""`), the StorageClass's own `reclaimPolicy` takes precedence; this value has no effect.

---

## Install ReportPortal

From the repository root:

```bash
helm install reportportal ./reportportal \
  --namespace reportportal \
  --create-namespace \
  -f test/fs-values.yaml \
  --set uat.superadminInitPasswd.password="ChangeMe123"
```

Or from the Helm repo:

```bash
helm repo add reportportal https://k8s.reportportal.io
helm repo update

helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set storage.type=filesystem \
  --set storage.volume.storageClassName=local-path \
  --set storage.volume.accessModes[0]=ReadWriteOnce \
  --set minio.install=false \
  --set uat.superadminInitPasswd.password="ChangeMe123"
```

---

## Verify Storage

```bash
# PVC should be Bound
kubectl get pvc -n reportportal

# Pods that mount the volume should be Running
kubectl get pods -n reportportal

# Check API logs for storage errors
kubectl logs -n reportportal deployment/reportportal-api --tail=50 | grep -i storage
```

Expected PVC name: `<release-name>-shared-volume-claim` (e.g. `reportportal-shared-volume-claim`).

---

## Access ReportPortal

**Rancher Desktop** (Traefik ingress, default in `test/fs-values.yaml`):

```bash
kubectl get ingress -n reportportal
```

Open `http://localhost` in your browser (add `127.0.0.1 localhost` to `/etc/hosts` if needed).

**Minikube:**

```bash
minikube tunnel   # in a separate terminal, if using LoadBalancer
kubectl get ingress -n reportportal
```

Default credentials: `superadmin` / the password you set with `uat.superadminInitPasswd.password`.

---

## Limitations

- **Single-node only** when using `local-path` with `ReadWriteOnce`. Adding worker nodes can prevent multiple pods from sharing the volume.
- **Not for production** multi-node clusters — use S3 or a true ReadWriteMany storage class (EFS, NFS, Filestore).
- **Data locality** — files live on the node's disk. Back up the PVC or node directory if you need to preserve data.

---

## Troubleshooting

### PVC stuck in Pending

```bash
kubectl describe pvc -n reportportal
```

Common causes:

- `accessModes: [ReadWriteMany]` with `local-path` — change to `[ReadWriteOnce]`
- `storageClassName` does not match any provisioner — use `kubectl get sc` and pick an existing class
- The selected StorageClass or CSI driver cannot satisfy the requested access mode

### Pods fail with volume mount errors

```bash
kubectl describe pod -n reportportal <pod-name>
```

Check the pod events for mount errors and confirm that the selected StorageClass supports the requested access mode.

### Analyzer `PermissionError` with non-root / hardened images

**Background — why this matters:** Starting with Docker Hardened Images (DHI), the `service-auto-analyzer` image runs as a non-root user (`uid=65532`) rather than `root`. The other ReportPortal services (`serviceapi`, `uat`, `servicejobs`) still run as root by default and create their per-project directories (e.g. `/data/storage/prj-1/`) with owner-only write permissions. If the analyzer ever needed to write to those same directories it would get a `PermissionError`.

**How the chart avoids this:** the analyzer is pointed at its own isolated subdirectory via `storage.volume.analyzerPath` (default: `analyzer`), so `FILESYSTEM_DEFAULT_PATH` inside the container resolves to `/data/storage/analyzer`. The analyzer creates and owns everything under that subtree itself and never touches the `prj-*` directories that the other services manage. This matches [upstream ReportPortal's reference configuration](https://github.com/reportportal/reportportal/blob/master/docker-compose.yml).

You can verify the correct layout after deployment:

```bash
kubectl exec -n reportportal -it reportportal-analyzer-0 -- ls -la /data/storage
# Expected:
# drwx------  65532:65532 analyzer/     ← analyzer's private subtree
# drwxr-x--x  root:root   prj-1/        ← api-owned, analyzer never writes here
# drwxr-x--x  root:root   prj-keystore/
```

> **Important — `storage.volume.analyzerPath`:** if you customise `storage.volume.defaultPath`, keep `analyzerPath` set to a non-empty subpath (default `analyzer`) so the analyzer's storage remains isolated. Setting `analyzerPath: ""` would point the analyzer at the same root as the other services and will cause `PermissionError` when running a non-root image.

**`fix-volume-permissions` init container:** even with path isolation, a `PermissionError` can still occur when first deploying a DHI image on top of an existing PVC where `/data/storage/analyzer/` was previously created as `root:root` (for example, after an in-place image upgrade from a non-hardened build). To handle this bootstrap case, the chart adds a `fix-volume-permissions` init container to the analyzer StatefulSet whenever `storage.type: filesystem` and `serviceanalyzer.fixVolumePermissions.enabled: true` (default). It runs as root and executes:

```sh
mkdir -p /data/storage/analyzer &&
chown -R 65532:65532 /data/storage/analyzer &&
chmod -R u+rwX,go-rwx /data/storage/analyzer
```

This targets only the `analyzer` subdirectory (not the whole shared volume), transfers existing data to the configured analyzer UID/GID, and removes group/other access. The defaults are `serviceanalyzer.fixVolumePermissions.user: 65532` and `group: 65532`; override them if the analyzer image uses another UID/GID.

After a successful recursive update, the init container creates a versioned marker named `.permissions-v1-<uid>-<gid>` in the analyzer directory. On later pod restarts it detects this marker and skips the expensive recursive `chown` and `chmod`. Changing the configured UID/GID produces a different marker and automatically runs the migration again.

The init container logs whether it applied or skipped the update:

```bash
kubectl logs -n reportportal reportportal-analyzer-0 \
  -c fix-volume-permissions
```

To disable the init container (e.g. when all images run as root):

```yaml
serviceanalyzer:
  fixVolumePermissions:
    enabled: false
```

`fsGroup` is **not** an effective alternative on Rancher Desktop/k3s: the bundled `local-path-provisioner` backs its PersistentVolumes with the `hostPath` volume type, and Kubernetes explicitly skips `fsGroup` ownership management for `hostPath` volumes.

### Multi-Attach error (after adding nodes)

This happens when a ReadWriteOnce volume is used across nodes. Switch to S3, use a ReadWriteMany storage class, or keep the cluster single-node.
