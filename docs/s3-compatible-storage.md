# S3-Compatible Object Storage

ReportPortal stores binary data (test attachments, user avatars, plugins, integration secrets, and machine-learning analyzer models) in object storage.

`service-api`, `service-jobs`, and `service-auto-analyzer` interact with storage through [Apache OpenDAL](https://opendal.apache.org/) using its S3 backend. This allows ReportPortal to work seamlessly with solutions implementing the Amazon S3 API.

## Supported Storage Providers

| Provider | Status | Notes |
|----------|--------|-------|
| **SeaweedFS** | Officially supported & default | Deployed automatically with the chart as a lightweight, high-performance embedded S3 gateway. |
| **MinIO** | Supported | Connect an existing or external MinIO deployment via `storage.type: s3-compatible`. |
| **Amazon S3** | Officially supported | Dedicated AWS integration via `storage.type: aws-s3`. See [S3 Storage on EKS](s3-storage-eks.md). |
| **Other S3-Compatible Providers** | Potentially compatible via OpenDAL | Systems like Rook Ceph RGW, Garage, Cloudflare R2, and other S3-compliant gateways. |

### Note on Other S3-Compatible Storage Solutions

Because ReportPortal uses Apache OpenDAL's S3 backend, a wide range of S3-compliant object storage systems can be used.

Compatibility depends on each provider's implementation of the S3 API and its specific configuration options. To ensure proper operation with ReportPortal, the target storage provider should support standard AWS Signature Version 4 authentication and path-style bucket addressing. We recommend validating your chosen storage configuration in a test environment prior to production rollout.

## Table of Contents

- [Storage types](#storage-types)
- [Configuration Reference](#configuration-reference)
- [Bundled SeaweedFS (Default)](#bundled-seaweedfs-default)
- [External MinIO](#external-minio)
- [Other S3-Compatible Storage Solutions](#other-s3-compatible-storage-solutions)
- [Bucket Strategy](#bucket-strategy)
- [Analyzer Storage Path](#analyzer-storage-path)
- [Bucket Creation](#bucket-creation)
- [Credentials & Security](#credentials--security)
- [Upgrade Notes](#upgrade-notes)
- [Troubleshooting](#troubleshooting)

## Storage types

| `storage.type` | Use Case | Endpoint | Authentication |
|----------------|----------|----------|----------------|
| `s3-compatible` (default) | SeaweedFS, MinIO, Ceph RGW, and other S3 gateways | `storage.endpoint` or the bundled SeaweedFS service | Access key and secret key |
| `aws-s3` | Native Amazon S3 | Resolved automatically from `storage.region` | IAM Roles for Service Accounts (IRSA), node instance profile, or static keys |
| `filesystem` | Shared PersistentVolumeClaim | N/A | N/A |

> **Note:** The legacy values `minio` and `s3` have been superseded. If used, the chart will display a helpful error message guiding you to set `storage.type: s3-compatible` or `storage.type: aws-s3`.

## Configuration Reference

The chart configures uniform `DATASTORE_*` environment variables for `service-api`, `service-jobs`, and `service-auto-analyzer`:

| Helm Value | Environment Variable | OpenDAL S3 Parameter | Description |
|------------|----------------------|----------------------|-------------|
| `storage.type` | `DATASTORE_TYPE` | Backend selector | `s3-compatible` or `aws-s3` |
| `storage.endpoint`, `ssl`, `port` | `DATASTORE_ENDPOINT` | `endpoint` | Constructed URL for `s3-compatible` storage |
| `storage.region` | `DATASTORE_REGION` | `region` | Signing region for SigV4 (e.g. `us-east-1`) |
| `storage.accesskey` or Secret | `DATASTORE_ACCESSKEY` | `access_key_id` | S3 access key |
| `storage.secretkey` or Secret | `DATASTORE_SECRETKEY` | `secret_access_key` | S3 secret key |
| `storage.bucket.bucketDefaultName` | `DATASTORE_DEFAULTBUCKETNAME` | `bucket` | Target bucket name |

### Endpoint Configuration (`s3-compatible`)

`storage.endpoint` accepts a **host name only** (do not include `http://`, `https://`, or port numbers):

| Parameter | Description | Result |
|-----------|-------------|--------|
| `storage.endpoint` | Host or service name | `<host>` |
| `storage.ssl` | Protocol selection (`true` for HTTPS, `false` for HTTP) | `https://` or `http://` |
| `storage.port` | Custom port number (leave empty for standard 80/443) | `:<port>` |

When `storage.endpoint` is omitted and `seaweedfs.install` is set to `true`, ReportPortal automatically connects to the internal SeaweedFS cluster service (`<release>-seaweedfs-all-in-one.<namespace>.svc:8333`).

## Bundled SeaweedFS (Default)

ReportPortal packages the [official SeaweedFS Helm chart](https://seaweedfs.github.io/seaweedfs/helm) as its default storage provider. The default values deploy an all-in-one instance (master, volume, filer, and S3 gateway) with persistent storage.

```yaml
storage:
  type: s3-compatible
  region: ""
  accesskey: rpuser
  secretkey: rppassword
  bucket:
    type: single
    bucketDefaultName: rp-bucket

seaweedfs:
  install: true
```

> **Evaluation and Production Considerations:**
> The default bundled SeaweedFS deployment runs as a single replica with a 10Gi `ReadWriteOnce` persistent volume, ideal for evaluation, development, and standard workloads.
>
> For high-availability, distributed clustering, or specialized storage classes, you can customize the SeaweedFS configuration under the `seaweedfs:` values section, or connect ReportPortal to an external enterprise storage cluster by setting `seaweedfs.install: false`.

### Customizing Credentials with Bundled SeaweedFS

If you customize the default access key and secret key, update both the `storage.*` values and the bundled SeaweedFS admin credentials so they remain aligned:

```yaml
storage:
  accesskey: myuser
  secretkey: mypassword
  bucket:
    bucketDefaultName: my-bucket

seaweedfs:
  s3:
    credentials:
      admin:
        accessKey: myuser
        secretKey: mypassword
```

The SeaweedFS PVC includes the `helm.sh/resource-policy: keep` annotation, safeguarding your data from accidental deletion during Helm upgrades or uninstalls.

## External MinIO

MinIO is fully supported by ReportPortal. To connect to an existing MinIO instance, specify your endpoint details, credentials, and disable the bundled SeaweedFS chart:

```yaml
storage:
  type: s3-compatible
  endpoint: "minio.minio.svc"
  ssl: false
  port: 9000
  region: ""
  accesskey: "minio"
  secretkey: "minio123"
  bucket:
    type: single
    bucketDefaultName: rp-bucket

seaweedfs:
  install: false
```

Ensure the target bucket (e.g. `rp-bucket`) is created in MinIO prior to deploying ReportPortal.

## Other S3-Compatible Storage Solutions

ReportPortal can connect to external S3-compatible object storage solutions—including external SeaweedFS clusters, Ceph Object Gateway (RGW), Garage, Cloudflare R2, and other compliant services.

Use the standard `s3-compatible` configuration parameters:

```yaml
storage:
  type: s3-compatible
  endpoint: "s3.example.internal"
  ssl: true
  port: 443
  region: "YOUR_REGION"
  accesskey: "YOUR_ACCESS_KEY"
  secretkey: "YOUR_SECRET_KEY"
  bucket:
    type: single
    bucketDefaultName: "reportportal-data"

seaweedfs:
  install: false
```

Ensure the target bucket is created and your credentials have full read, write, and delete permissions on it.

## Bucket Strategy

Both strategies store everything inside one bucket, `bucketDefaultName`. The default is `multi`.

| Strategy | `storage.bucket.type` | Object Layout |
|----------|-----------------------|---------------|
| **Multi** (default) | `multi` | Each project is a folder named `<bucketMultiPrefix><projectId><bucketMultiPostfix>` (for example `prj-1/...`). Plugins are under `<bucketDefaultName>/` and the integration salt is in `<bucketMultiPrefix><bucketMultiSaltName>/`. 26.0 stored each project in its own bucket, so 26.0 data must be copied once. See the [migration guide](migration-26.0-to-26.1.md). |
| **Single** | `single` | Projects are isolated by prefix (`project-data/<projectId>/...`). |

In `multi` mode, the object hierarchy within `bucketDefaultName` is structured as:

- `<bucketMultiPrefix><projectId>/...`: Launch and test item attachments (for example `prj-1/...`)
- `<bucketMultiPrefix>users/...`: User profile assets
- `<bucketMultiPrefix><bucketMultiSaltName>/secret-integration-salt`: Integration encryption salt
- `<bucketDefaultName>/...`: Installed plugin packages (a folder named like the bucket, for example `rp-bucket/rp-bucket/<plugin>.jar`)

In `single` mode, the object hierarchy within `bucketDefaultName` is structured as:

- `project-data/<projectId>/...`: Launch and test item attachments
- `plugins/...`: Installed plugin packages
- `integration-secrets/...`: Integration credentials and encryption material
- `user-data/...`: User profile assets

The database stores the same relative path in both releases (for example `1/2026-11/...` in `multi`, `project-data/1/...` in `single`). The bucket is never stored in the database.

Changing `storage.bucket.type` on an existing deployment does not automatically relocate objects. When transitioning between strategies, existing data should be migrated accordingly (see [Upgrade Notes](#upgrade-notes)).

## Analyzer Storage Path

The auto-analyzer stores its machine-learning binary models in `bucketDefaultName` under a dedicated folder path:

```text
<bucketDefaultName>/<analyzerPath>/<bucketMultiPrefix><projectId>/...
# Default layout: rp-bucket/analyzer/prj-<projectId>/...
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `storage.volume.analyzerPath` | `analyzer` | Relative subfolder in the bucket for analyzer models. |
| `storage.bucket.bucketMultiPrefix` | `prj-` | Prefix applied to project model directories. |

## Bucket Creation

| Environment | Bucket Provisioning |
|-------------|---------------------|
| **Bundled SeaweedFS** | Handled automatically. ReportPortal initializes the default bucket upon saving initial system assets during startup. |
| **External MinIO & S3-Compatible Storage** | Pre-create the bucket specified in `storage.bucket.bucketDefaultName` before installing ReportPortal. |
| **Amazon S3** (`aws-s3`) | Pre-create the bucket via AWS Console, CLI, or Terraform before deployment. |

The configured storage user or IAM role requires read, write, list, and delete permissions on the target bucket.

## Credentials & Security

For production deployments, we strongly recommend referencing credentials from a Kubernetes Secret rather than placing them in plain text:

```yaml
storage:
  secretName: rp-storage-credentials
  accesskeyName: access-key
  secretkeyName: secret-key
```

When using the bundled SeaweedFS with a shared Kubernetes Secret, configure the SeaweedFS admin credentials to reference the same Secret:

```yaml
seaweedfs:
  s3:
    enableAuth: true
    credentials:
      admin:
        existingSecret: rp-storage-credentials
        accessKeyKey: access-key
        secretKeyKey: secret-key
```

When deploying on AWS EKS with `storage.type: aws-s3`, you can omit static keys and use IAM Roles for Service Accounts (IRSA) directly.

## Upgrade Notes

The Helm chart manages application deployment and configuration; it does not automatically move or migrate existing object storage files between different storage backends or bucket layouts.

### Key Changes in ReportPortal 26.x

1. **SeaweedFS is the new default bundled storage:** The embedded MinIO sub-chart has been replaced by SeaweedFS. `helm upgrade` removes the MinIO Deployment, Service, and Secret of the release (the volume is kept). Upgrading with default values deploys a fresh, empty SeaweedFS instance. To move your MinIO data to SeaweedFS, follow the [migration guide](migration-26.0-to-26.1.md).
2. **Multi layout inside one bucket:** The chart defaults to `storage.bucket.type: multi`. In 26.1, `multi` projects are folders inside `bucketDefaultName` instead of separate buckets as in 26.0. Setting `multi` alone does not make 26.0 data readable. Copy it as described in the [migration guide](migration-26.0-to-26.1.md). Keep `bucketMultiPrefix`, `bucketMultiPostfix` and `bucketMultiSaltName` unchanged.
3. **Storage type naming:** Legacy values `minio` and `s3` are replaced by `s3-compatible` and `aws-s3`.
4. **Default credentials:** The default demo secret key is now `rppassword` (replacing `miniopassword`).

### Recommended Pre-Upgrade Checklist

1. **Back up your data:** Create a backup of your existing storage bucket or PVC and the PostgreSQL database.
2. **Review your storage target:**
   - To use the bundled SeaweedFS, follow the [migration guide](migration-26.0-to-26.1.md). It runs MinIO from the kept volume as the copy source and copies the objects with `mc mirror`.
   - For other targets, the 26.1 `multi` layout applies (projects as folders in `bucketDefaultName`). Copy the objects the same way.
3. **Preserve the integration encryption salt:**
   - Single-bucket mode stores the salt at `integration-secrets/secret-integration-salt`.
   - Multi-bucket mode stores the salt at `<bucketMultiPrefix><bucketMultiSaltName>/secret-integration-salt` (default `prj-keystore/secret-integration-salt`) inside `bucketDefaultName`.
   - Ensuring this file is preserved allows ReportPortal to decrypt existing third-party integration settings without re-entering credentials.

## Troubleshooting

| Symptom | Probable Cause | Recommended Action |
|---------|----------------|--------------------|
| `storage.type "minio" is no longer supported` | Previous version values file in use | Update your values to use `storage.type: s3-compatible`. |
| `storage.endpoint must be a host name without scheme` | URL scheme included in endpoint | Provide host name only (e.g. `minio.example.com`) and configure protocol with `storage.ssl`. |
| `storage.endpoint is required when storage.type is s3-compatible and seaweedfs.install is false` | External storage chosen without providing endpoint | Set `storage.endpoint` to point to your S3 service. |
| `storage.region is required when storage.type is aws-s3` | Missing AWS region | Specify the appropriate region in `storage.region` (e.g. `us-east-1`). |
| `NoSuchBucket` / Bucket not found | Target bucket has not been created | Create the bucket in your storage service, or verify the bucket name matches `storage.bucket.bucketDefaultName`. |
| `SignatureDoesNotMatch` / `AccessDenied` | Credential or region mismatch | Verify access/secret keys and ensure `storage.region` matches the region configured on your storage gateway. |
| Connection refused to `...-minio:9000` | Values still reference removed internal MinIO | Update the endpoint to your new storage service or enable bundled SeaweedFS. |

### Inspecting Bundled SeaweedFS

You can inspect the bundled SeaweedFS instance using the command line:

```bash
# List all buckets
kubectl -n <namespace> exec deploy/<release>-seaweedfs-all-in-one -- \
  sh -c "echo 's3.bucket.list' | weed shell"

# List files within the bucket
kubectl -n <namespace> exec deploy/<release>-seaweedfs-all-in-one -- \
  sh -c "echo 'fs.ls /buckets/rp-bucket' | weed shell"

# View SeaweedFS logs
kubectl -n <namespace> logs deploy/<release>-seaweedfs-all-in-one
```
