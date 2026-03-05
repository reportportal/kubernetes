# ReportPortal Storage Types

The chart supports **four storage backends**. Set `storage.type` and enable/disable the matching subchart. All options are defined in [reportportal/values.yaml](../reportportal/values.yaml).

| Type        | Use case                          | Subchart to install | Default in chart |
|------------|------------------------------------|----------------------|------------------|
| **SeaweedFS** | S3-compatible, Apache 2.0 | `seaweedfs`          | ✅ Default       |
| **MinIO**     | S3-compatible, self-hosted (AGPL)     | `minio`              | —                |
| **S3**       | AWS S3 or any S3-compatible API       | none                 | —                |
| **FS**        | Shared filesystem (NFS, Filestore…)   | none                 | —                |

Use **Helm `--set`** for quick overrides or a **values file** (`-f`) for full config. Chart path: `./reportportal` (from this repo) or `reportportal/reportportal` (if added as Helm repo).

---

## 1. SeaweedFS (default, recommended)

Apache 2.0 licensed, S3-compatible object storage. One pod (all-in-one) with one PVC; S3 API on port 8333. Credentials come from `storage.accesskey` / `storage.secretkey` in values.

**Helm (no extra flags — defaults):**

```bash
helm upgrade --install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  reportportal
```

Or explicitly:

```bash
helm upgrade --install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set storage.type=seaweedfs \
  --set seaweedfs.install=true \
  --set minio.install=false \
  reportportal
```

**Optional values file** (e.g. `my-values.yaml`):

```yaml
storage:
  type: seaweedfs
  accesskey: rpuser
  secretkey: miniopassword
  # endpoint/port left empty → internal service
  ssl: false

seaweedfs:
  install: true
  allInOne:
    data:
      size: "20Gi"
  s3:
    enableAuth: true
    credentials:
      admin:
        accessKey: rpuser
        secretKey: miniopassword

minio:
  install: false
```

Install with: `helm upgrade --install my-release -f my-values.yaml reportportal`

---

## 2. MinIO

Self-hosted S3-compatible storage (AGPL). Chart deploys MinIO as a dependency; API on port 9000.

**Helm:**

```bash
helm upgrade --install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set storage.type=minio \
  --set seaweedfs.install=false \
  --set minio.install=true \
  reportportal
```

**Optional values file:**

```yaml
storage:
  type: minio
  accesskey: rpuser
  secretkey: miniopassword
  endpoint: ""   # empty = internal MinIO service
  ssl: false
  port: 9000
  bucket:
    type: multi
    bucketDefaultName: "rp-bucket"

seaweedfs:
  install: false

minio:
  install: true
  auth:
    rootUser: rpuser
    rootPassword: miniopassword
  persistence:
    size: 50Gi
```

For credentials from a Kubernetes secret, use `storage.secretName`, `storage.accesskeyName`, `storage.secretkeyName` and MinIO’s `auth.existingSecret` (see values.yaml).

---

## 3. S3

Use AWS S3 or any S3-compatible endpoint (no built-in object store). Set `storage.type=s3`, disable both SeaweedFS and MinIO.

**Helm (minimal — e.g. AWS with IRSA):**

```bash
helm upgrade --install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set storage.type=s3 \
  --set storage.region=us-east-1 \
  --set seaweedfs.install=false \
  --set minio.install=false \
  reportportal
```

**With inline credentials:**

```bash
helm upgrade --install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set storage.type=s3 \
  --set storage.region=us-east-1 \
  --set storage.accesskey=AKIA... \
  --set storage.secretkey=... \
  --set seaweedfs.install=false \
  --set minio.install=false \
  reportportal
```

**Optional values file (AWS S3, IAM role / IRSA):**

```yaml
storage:
  type: s3
  accesskey: ""
  secretkey: ""
  region: "us-east-1"
  ssl: true
  bucket:
    type: single
    bucketDefaultName: "my-reportportal-bucket"

seaweedfs:
  install: false

minio:
  install: false
```

**Optional values file (custom S3-compatible endpoint):**

```yaml
storage:
  type: s3
  accesskey: mykey
  secretkey: mysecret
  endpoint: "s3.example.com"
  port: 443
  ssl: true
  region: "us-east-1"
  bucket:
    type: single
    bucketDefaultName: "reportportal"

seaweedfs:
  install: false

minio:
  install: false
```

For EKS with IRSA, set `global.serviceAccount.annotations.eks\.amazonaws\.com/role-arn` (see values.yaml).

---

## 4. FS (filesystem)

Use a shared filesystem (NFS, GKE Filestore, etc.). The chart creates a PVC and mounts it at `storage.volume.defaultPath` in API, UAT, Jobs, and Analyzer pods.

**Helm:**

```bash
helm upgrade --install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set storage.type=filesystem \
  --set storage.volume.capacity=10Gi \
  --set storage.volume.storageClassName=standard \
  --set seaweedfs.install=false \
  --set minio.install=false \
  reportportal
```

**Optional values file:**

```yaml
storage:
  type: filesystem
  volume:
    defaultPath: "/data/storage"
    capacity: 10Gi
    storageClassName: "standard"   # e.g. standard-rwx for GKE Filestore

seaweedfs:
  install: false

minio:
  install: false
```

---

## Summary: key values per type

| Type       | `storage.type` | `seaweedfs.install` | `minio.install` | Extra (examples) |
|-----------|----------------|--------------------|-----------------|--------------------|
| SeaweedFS | `seaweedfs`    | `true`             | `false`         | —                  |
| MinIO     | `minio`        | `false`            | `true`          | `storage.port=9000` |
| S3        | `s3`           | `false`            | `false`         | `storage.region`, credentials or IRSA |
| FS        | `filesystem`   | `false`            | `false`         | `storage.volume.capacity`, `storageClassName` |

All storage-related parameters (bucket, secretName, endpoint, ssl, volume, etc.) are documented in [reportportal/values.yaml](../reportportal/values.yaml).
