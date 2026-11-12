# S3-Compatible Object Storage

ReportPortal stores binary data (attachments, analyzer models) through
[Apache OpenDAL](https://opendal.apache.org/). `storage.type: s3-compatible`
speaks the S3 API.

Tested with this chart: the bundled SeaweedFS (default) and an external MinIO.
The same values also target other S3 API servers (external SeaweedFS, Rook Ceph
RGW, Garage, Cloudflare R2, and similar gateways). Those are supported and have
not been tested.

For Amazon S3 specifically, use `storage.type: aws-s3` — see
[S3 Storage on EKS](s3-storage-eks.md).

## Table of Contents

- [Storage types](#storage-types)
- [Values → environment variables → OpenDAL](#values--environment-variables--opendal)
- [Bundled SeaweedFS (default)](#bundled-seaweedfs-default)
- [External MinIO](#external-minio)
- [Other S3-compatible servers](#other-s3-compatible-servers)
- [Bucket strategy](#bucket-strategy)
- [Credentials](#credentials)
- [Upgrade notes](#upgrade-notes)
- [Troubleshooting](#troubleshooting)

## Storage types

| `storage.type` | When to use | Endpoint | Credentials |
|----------------|-------------|----------|-------------|
| `s3-compatible` | Any S3 API server (default) | `storage.endpoint` or bundled SeaweedFS | Access / secret key (required for most gateways) |
| `aws-s3` | Amazon S3 | Resolved by region | Access / secret key **or** empty keys + IRSA / instance profile |
| `filesystem` | Shared PVC | N/A | N/A |

Legacy values `minio` and `s3` are rejected by the chart. Use `s3-compatible`
and `aws-s3` respectively.

## Values → environment variables → OpenDAL

The chart renders the same `DATASTORE_*` variables for `service-api`,
`service-jobs`, and `service-auto-analyzer`:

| Helm value | Env var | OpenDAL `s3` option |
|------------|---------|---------------------|
| `storage.type` | `DATASTORE_TYPE` | selects `s3` scheme (`s3-compatible` / `aws-s3`) |
| `storage.endpoint` (+ `ssl` / `port`) | `DATASTORE_ENDPOINT` | `endpoint` (s3-compatible only) |
| `storage.region` | `DATASTORE_REGION` | `region` (SigV4 scope) |
| `storage.accesskey` / secret | `DATASTORE_ACCESSKEY` | `access_key_id` |
| `storage.secretkey` / secret | `DATASTORE_SECRETKEY` | `secret_access_key` |
| `storage.bucket.bucketDefaultName` | `DATASTORE_DEFAULTBUCKETNAME` | `bucket` |

OpenDAL defaults to path-style addressing and AWS Signature Version 4, which
matches the tested SeaweedFS and MinIO gateways. Providers that require
virtual-host style only can pass extra OpenDAL options to the analyzer via
`serviceanalyzer.extraEnvs`:

```yaml
serviceanalyzer:
  extraEnvs:
    - name: DATASTORE_OPENDAL_OPTIONS
      value: '{"enable_virtual_host_style": "true"}'
```

(`service-api` / `service-jobs` do not expose a generic OpenDAL options map;
prefer path-style endpoints for those services.)

### Endpoint (`s3-compatible`)

`storage.endpoint` is a **host name only** — no `http(s)://` and no port. The
final URL is built from three values:

| Value | Meaning | Result |
|-------|---------|--------|
| `storage.endpoint` | Host name | `<host>` |
| `storage.ssl` | `false` = http, `true` = https | `http://` / `https://` |
| `storage.port` | Optional; empty = scheme default (80 / 443) | `:<port>` |

If `storage.endpoint` is empty, the chart uses the bundled SeaweedFS gateway
(only valid when `seaweedfs.install: true`). Passing a value that starts with
`http://` or `https://` fails with an explicit error, so `ssl` can never
contradict the endpoint.

## Bundled SeaweedFS (default)

The chart depends on the
[official SeaweedFS Helm chart](https://seaweedfs.github.io/seaweedfs/helm).
Defaults install an all-in-one Deployment (master + volume + filer + S3) with a
PVC and create `storage.bucket.bucketDefaultName` via the SeaweedFS post-install
hook.

> **Demo / evaluation setup only.** The bundled SeaweedFS is a single node:
> one replica (`Recreate` strategy), one `ReadWriteOnce` PVC (`10Gi`), no
> replication and no high availability. For anything else — more replicas, HA or
> replicated topology, resources, storage class, ingress, metrics, TLS — either
> override the upstream chart values under the `seaweedfs:` key (they are passed
> through unchanged and are **your** responsibility), or set
> `seaweedfs.install: false` and use your own S3-compatible service or
> `storage.type: aws-s3`.

```yaml
storage:
  type: s3-compatible
  accesskey: rpuser
  secretkey: rppassword
  bucket:
    type: single
    bucketDefaultName: rp-bucket

seaweedfs:
  install: true
```

ReportPortal services do **not** create buckets. The bundled chart creates the
default bucket; for an external gateway you must create it yourself.

## External MinIO

Tested. Set `storage.endpoint` and disable the bundled chart. Create
`bucketDefaultName` on MinIO before installing ReportPortal.

```yaml
storage:
  type: s3-compatible
  endpoint: "minio.minio.svc"
  ssl: false
  port: 9000
  accesskey: "minio"
  secretkey: "minio123"
  bucket:
    type: single
    bucketDefaultName: rp-bucket

seaweedfs:
  install: false
```

## Other S3-compatible servers

Supported with the same fields as MinIO (`endpoint` host, `ssl`, `port`,
credentials, `seaweedfs.install: false`, and a bucket that already exists).
Not tested: external SeaweedFS, Rook Ceph RGW, Garage, Cloudflare R2, and
similar gateways.

## Bucket strategy

| `storage.bucket.type` | Behaviour |
|-----------------------|-----------|
| `single` (default) | One bucket (`bucketDefaultName`); projects are prefixes. Sets `RP_FEATURE_FLAGS=singleBucket` on api/jobs. |
| `multi` | One bucket per project (`bucketMultiPrefix` + project id). Not recommended for cloud S3. |

The analyzer always writes into the single default bucket under
`<analyzerPath>/<bucketMultiPrefix><projectId>/` (for example
`analyzer/prj-2/...`), regardless of `bucket.type`.

**Buckets must already exist** for OpenDAL clients. The bundled SeaweedFS
`createBuckets` hook covers the default install; external providers need a
pre-created bucket.

## Credentials

Prefer a Kubernetes Secret in production:

```yaml
storage:
  secretName: rp-storage-credentials
  accesskeyName: access-key
  secretkeyName: secret-key
```

When using the bundled SeaweedFS with a shared secret, also point the SeaweedFS
S3 admin identity at it:

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

## Upgrade notes

1. **`storage.bucket.type` default is now `single`.** To keep per-project
   buckets, set `storage.bucket.type: multi` explicitly.
2. **Bundled MinIO is removed.** The chart installs SeaweedFS instead. MinIO PVC
   data is **not** migrated automatically. Options:
   - Keep an external MinIO and set `storage.endpoint` + `seaweedfs.install: false`.
   - Copy objects with `mc mirror` / `rclone` into the new SeaweedFS (or other)
     bucket, then switch the chart.
3. **Legacy `storage.type` values `minio` and `s3` fail** at template time.
   Replace them with `s3-compatible` and `aws-s3`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `storage.type "minio" is no longer supported` | Old overlay | Set `storage.type: s3-compatible` |
| `storage.endpoint must be a host name without scheme` | Endpoint set as `http(s)://...` | Use host only and set `storage.ssl` / `storage.port` |
| `storage.endpoint is required` | External S3-compatible without endpoint | Set `storage.endpoint` or `seaweedfs.install: true` |
| `storage.region is required` | `aws-s3` without region | Set `storage.region` (e.g. `eu-central-1`) |
| Analyzer / API: invalid bucket / NoSuchBucket | Bucket missing or wrong name | Create `bucketDefaultName` on the gateway; check the SeaweedFS bucket hook |
| SignatureDoesNotMatch / AccessDenied | Wrong keys or region | Align `accesskey`/`secretkey`/`region` with the gateway config |
| Connection refused to `…-minio:9000` | Overlay still points at MinIO | Update endpoint or enable SeaweedFS (`…-seaweedfs-all-in-one:8333`) |
