# ReportPortal Storage Configuration Examples

This document contains common storage configurations for different environments. Copy the relevant section into a values file and pass it with `-f` when installing or upgrading the chart.

**Current chart defaults (see [reportportal/values.yaml](../reportportal/values.yaml)):**  
- **MinIO**: `storage.type: minio`, inline `accesskey`/`secretkey`, `minio.install: true`.  
- **S3**: set `storage.type: s3`, leave credentials empty for IRSA, set `minio.install: false`.  
- **Filesystem**: `storage.type: filesystem`, `storage.volume.defaultPath: "/data/storage"` (mount path and env for API/UAT/Jobs/Analyzer), `minio.install: false`.

## Usage Examples

Use a custom values file (e.g. `storage-examples.yaml`) with the chart. When using the repo locally, point to the chart path `./reportportal`:

```bash
# Install with a storage example file
helm install my-release ./reportportal -f storage-examples.yaml

# Or merge with default values and override storage only
helm install my-release ./reportportal -f values.yaml -f storage-examples.yaml
```

## Example 1: MinIO Storage (Default - Good for Development)

Uses the built-in MinIO service for object storage.

```yaml
storage:
  type: minio
  # MinIO credentials (inline - not recommended for production)
  accesskey: &storageAccessKey rpuser
  secretkey: &storageSecretKey miniopassword
  # Use internal MinIO service
  endpoint: ""
  ssl: false
  port: 9000
  bucket:
    type: single  # Simpler for development
    bucketDefaultName: "rp-bucket"

minio:
  install: true
  auth:
    rootUser: *storageAccessKey
    rootPassword: *storageSecretKey
```

## Example 2: MinIO Storage with Secrets (Production)

Uses the built-in MinIO service with Kubernetes secrets for secure credential management.

```yaml
# Create a Kubernetes secret first:
# kubectl create secret generic reportportal-minio-secret \
#   --from-literal=access-key=your-minio-access-key \
#   --from-literal=secret-key=your-minio-secret-key

storage:
  type: minio
  # Reference to Kubernetes secret containing MinIO credentials
  secretName: "reportportal-minio-secret"
  accesskeyName: "access-key"
  secretkeyName: "secret-key"
  # Use internal MinIO service
  endpoint: ""
  ssl: false
  port: 9000
  bucket:
    type: single  # Recommended for production
    bucketDefaultName: "rp-bucket"

minio:
  install: true
  auth:
    existingSecret: "reportportal-minio-secret"
    rootUserSecretKey: "access-key"
    rootPasswordSecretKey: "secret-key"
  persistence:
    size: 500Gi  # Adjust based on your storage needs
```

## Example 3: AWS S3 Storage with IAM Role (Production)

Uses AWS S3 with IAM role-based authentication (recommended for EKS).

```yaml
storage:
  type: s3
  # No credentials needed when using IAM roles
  accesskey: ""
  secretkey: ""
  # AWS region
  region: "us-east-1"
  bucket:
    type: single
    bucketDefaultName: "my-reportportal-bucket"
  # SSL enabled for S3
  ssl: true

# Enable IAM role for service account (EKS only)
global:
  serviceAccount:
    create: true
    name: reportportal
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/my-rp-s3-role"

# Disable MinIO since we're using S3
minio:
  install: false
```

## Example 4: AWS S3 Storage with Access Keys (Production)

Uses AWS S3 with access key authentication.

```yaml
storage:
  type: s3
  # Create a Kubernetes secret with your AWS credentials
  secretName: "reportportal-s3-credentials"
  accesskeyName: "access-key"
  secretkeyName: "secret-key"
  # AWS region
  region: "us-east-1"
  bucket:
    type: single
    bucketDefaultName: "my-reportportal-bucket"
  ssl: true

# Disable MinIO since we're using S3
minio:
  install: false
```

## Example 5: Filesystem Storage with GKE Filestore (Production)

Uses Google Filestore for shared filesystem storage. When `type: filesystem`, the chart mounts the volume at `storage.volume.defaultPath` inside API, UAT, Jobs, and Analyzer pods (and sets `DATASTORE_PATH` / `FILESYSTEM_DEFAULT_PATH` accordingly). Override `defaultPath` only if your PVC or storage backend expects a different path.

```yaml
storage:
  type: filesystem
  volume:
    # Optional: default is /data/storage (used as DATASTORE_PATH / FILESYSTEM_DEFAULT_PATH)
    defaultPath: "/data/storage"
    capacity: 1Ti  # Minimum for Filestore
    storageClassName: "standard-rwx"  # GKE Filestore storage class

# Disable MinIO since we're using filesystem
minio:
  install: false
```

## Example 6: Production S3 Storage with Single Bucket (Recommended)

**Recommended for production deployments.** Uses a single S3 bucket for all ReportPortal data, providing better cost management and simpler administration.

```yaml
storage:
  type: s3
  # Use IAM role for authentication (recommended for production)
  accesskey: ""
  secretkey: ""
  # AWS region
  region: "us-east-1"
  bucket:
    type: single  # Single bucket for all data
    bucketDefaultName: "reportportal-production-data"
  ssl: true

# Enable IAM role for service account (EKS only)
global:
  serviceAccount:
    create: true
    name: reportportal
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/reportportal-s3-role"

# Disable MinIO since we're using S3
minio:
  install: false
```

**Benefits of Single Bucket for Production:**
- **Cost Effective**: Fewer buckets mean lower S3 costs
- **Simpler Management**: One bucket to monitor and manage
- **Better Performance**: No need to create/manage multiple buckets
- **Easier Backup**: Single bucket simplifies backup strategies
- **IAM Simplicity**: Simpler IAM policies with one bucket

## Example 7: Custom S3-Compatible Storage (MinIO, Ceph, etc.)

Uses external S3-compatible storage service.

```yaml
storage:
  type: s3
  secretName: "reportportal-storage-credentials"
  accesskeyName: "access-key"
  secretkeyName: "secret-key"
  # Your S3-compatible service endpoint
  endpoint: "my-minio.example.com"
  port: 9000
  ssl: true
  bucket:
    type: single
    bucketDefaultName: "reportportal-bucket"

# Disable built-in MinIO since we're using external storage
minio:
  install: false
```

## MinIO Anchors

The following anchors are used for MinIO configuration and should be preserved when setting up MinIO storage:

```yaml
# MinIO access credentials
accesskey: &storageAccessKey rpuser
secretkey: &storageSecretKey miniopassword
```

These anchors are referenced throughout the ReportPortal configuration and ensure consistent MinIO setup across all services.
