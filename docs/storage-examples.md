# ReportPortal Storage Configuration Examples

This document contains common storage configurations for different environments. Copy the relevant section to your `values.yaml` or use with `--set-file` flag.

## Usage Examples

```bash
# Install with storage examples
helm install reportportal reportportal/reportportal -f storage-examples.yaml

# Or use specific example
helm install reportportal reportportal/reportportal --set-file storage=storage-examples.yaml
```

## Example 1: MinIO Storage (Default - Good for Development)

Uses the built-in MinIO service for object storage.

```yaml
storage:
  type: minio
  # MinIO credentials (inline - not recommended for production)
  accesskey: rpuser
  secretkey: miniopassword
  # Use internal MinIO service
  endpoint: ""
  ssl: false
  port: 9000
  bucket:
    type: single  # Simpler for development
    bucketDefaultName: "rp-bucket"
```

## Example 2: AWS S3 Storage with IAM Role (Production)

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

## Example 3: AWS S3 Storage with Access Keys (Production)

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

## Example 4: Filesystem Storage with GKE Filestore (Production)

Uses Google Filestore for shared filesystem storage.

```yaml
storage:
  type: filesystem
  volume:
    capacity: 1Ti  # Minimum for Filestore
    storageClassName: "standard-rwx"  # GKE Filestore storage class

# Disable MinIO since we're using filesystem
minio:
  install: false
```

## Example 5: Filesystem Storage with Local Storage (Development)

Uses local storage for development/testing.

```yaml
storage:
  type: filesystem
  volume:
    capacity: 10Gi
    storageClassName: "standard"
    volumeConfig:
      type: hostPath
      hostPath:
        path: "/data/reportportal"

# Disable MinIO since we're using filesystem
minio:
  install: false
```

## Example 6: Multi-Bucket S3 Storage (Advanced)

Uses multiple S3 buckets for different projects.

```yaml
storage:
  type: s3
  secretName: "reportportal-s3-credentials"
  accesskeyName: "access-key"
  secretkeyName: "secret-key"
  region: "us-east-1"
  bucket:
    type: multi
    bucketDefaultName: "rp-plugins-bucket"
    bucketMultiPrefix: "rp-project-"
    bucketMultiPostfix: ""
    bucketMultiSaltName: "keystore"
  ssl: true

# Disable MinIO since we're using S3
minio:
  install: false
```

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
