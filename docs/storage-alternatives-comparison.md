# Object Storage Alternatives for ReportPortal Helm Chart

Comparison of S3-compatible object storage options as replacements for MinIO in the
ReportPortal Kubernetes Helm chart. Evaluated against the actual chart requirements
and the `perf` / `beta` production environments.

---

## Why Replace MinIO?

MinIO changed its license from **Apache 2.0 to AGPL-3.0** in January 2021. The
`bitnami/minio` chart (`bitnamilegacy/minio` image) used by ReportPortal is built
from the current AGPL source. For organisations requiring a permissively-licensed
(Apache 2.0) self-hosted object store, a replacement is needed.

---

## Requirements

Derived from the chart templates and live deployments (`perf` namespace, `rpp-beta` cluster):

| # | Requirement | Detail |
|---|---|---|
| 1 | **Apache 2.0 license** | AGPL and SSPL are disqualifying |
| 2 | **S3-compatible API** | JClouds `minio` provider (used by `service-api`, `service-jobs`, `service-auto-analyzer`, `service-authorization`) connects via HTTP/S3 protocol |
| 3 | **Access key + secret key auth** | `DATASTORE_ACCESSKEY` / `DATASTORE_SECRETKEY` env vars |
| 4 | **Helm dependency** | Must be installable as a `Chart.yaml` dependency with `condition:` flag |
| 5 | **PVC-backed storage** | Data must survive pod restarts; `helm.sh/resource-policy: keep` annotation required |
| 6 | **HTTP endpoint** | Services connect via `DATASTORE_ENDPOINT=http://<host>:<port>` |
| 7 | **Multi-bucket support** | Bucket-per-project mode (`prj-` prefix) used in `perf`; single-bucket mode used in `beta` |

---

## Candidates Evaluated

### 1. SeaweedFS ✅ — **Selected**

| Property | Value |
|---|---|
| **License** | Apache 2.0 |
| **Helm chart** | `seaweedfs/seaweedfs` — [github.com/seaweedfs/seaweedfs](https://github.com/seaweedfs/seaweedfs) |
| **Chart repo** | `https://seaweedfs.github.io/seaweedfs/helm` |
| **Tested version** | 4.15.0 |
| **S3-compatible API** | Yes — S3 gateway on port 8333 |
| **Auth** | Access key + secret key via generated `seaweedfs_s3_config` JSON |
| **PVC** | Yes — `allInOne.data.type: persistentVolumeClaim` |
| **Helm dependency** | Yes — single `condition: seaweedfs.install` flag |
| **Demo footprint** | 1 pod (`allInOne` mode), 1 PVC |
| **Production mode** | Separate master / volume / filer StatefulSets with full HA |

**How it integrates:**

Services receive `DATASTORE_TYPE=minio` (the JClouds provider that speaks plain S3
protocol) pointing at the SeaweedFS S3 gateway. No service code changes required.

```
DATASTORE_TYPE=minio
DATASTORE_ENDPOINT=http://<release>-seaweedfs-all-in-one.<ns>.svc.cluster.local:8333
DATASTORE_ACCESSKEY=<from storage.accesskey>
DATASTORE_SECRETKEY=<from storage.secretkey>
```

**Helm chart key values (demo/test):**

```yaml
storage:
  type: seaweedfs
  accesskey: rpuser
  secretkey: mypassword

seaweedfs:
  install: true
  allInOne:
    enabled: true
    s3:
      enabled: true
      enableAuth: true
    data:
      type: persistentVolumeClaim
      size: 20Gi
  s3:
    enableAuth: true
    credentials:
      admin:
        accessKey: rpuser       # keeps in sync with storage.accesskey
        secretKey: mypassword   # keeps in sync with storage.secretkey
```

**Pros:**
- Apache 2.0 ✓
- Minimal demo footprint (1 pod + 1 PVC via `allInOne`)
- Scales to full production HA without changing the chart interface
- Actively maintained, large community
- Supports multi-bucket and single-bucket modes
- Auto-generates S3 auth config from credentials; secret survives upgrades
  (`helm.sh/resource-policy: keep`)

**Cons:**
- `allInOne` mode is not recommended for production (shared process, RWO PVC)
- S3 auth config is less flexible than MinIO's fine-grained IAM policies
- Default image is `chrislusf/seaweedfs` (Docker Hub), not a hardened image

---

### 2. Rook-Ceph ❌ — Eliminated

| Property | Value |
|---|---|
| **License** | Apache 2.0 |
| **S3-compatible API** | Yes — RADOS Object Gateway (RGW) |
| **Auth** | Yes — S3-compatible |
| **PVC** | Yes |
| **Helm dependency** | ❌ Not feasible |

**Why eliminated:**

Rook requires a cluster-wide operator and `CephCluster` CRD installed as a separate
infrastructure layer. It cannot be packaged as a simple `dependencies:` entry in
`Chart.yaml`. Requires dedicated nodes, raw block devices or pre-provisioned PVCs,
and a separate lifecycle from the application chart. It is an infrastructure platform,
not an application dependency.

---

### 3. GarageHQ ❌ — Eliminated

| Property | Value |
|---|---|
| **License** | **AGPL-3.0** ❌ |
| **S3-compatible API** | Yes |
| **Auth** | Yes |
| **PVC** | Yes (StatefulSet) |
| **Helm chart** | Minimal / community only |

**Why eliminated:**

GarageHQ uses the **AGPL-3.0** license — the same issue as MinIO. Does not meet the
Apache 2.0 requirement. Eliminated without further evaluation.

---

### 4. Zenko CloudServer (Scality) ⚠️ — Not recommended

| Property | Value |
|---|---|
| **License** | Apache 2.0 |
| **S3-compatible API** | Yes — original S3-compatible implementation |
| **Auth** | Yes |
| **PVC** | Yes |
| **Helm chart** | No official maintained chart |
| **Maintenance status** | Minimal — Scality focus shifted to enterprise products |

**Why not recommended:**

No actively maintained Helm chart. The project has low community momentum and the
upstream organisation no longer prioritises the open-source distribution. Not suitable
as a production dependency.

---

### 5. Apache Ozone ⚠️ — Not recommended

| Property | Value |
|---|---|
| **License** | Apache 2.0 |
| **S3-compatible API** | Yes |
| **Auth** | Yes |
| **PVC** | Yes |
| **Helm chart** | Exists but not well-maintained |
| **Designed for** | Large-scale HDFS / Hadoop environments |

**Why not recommended:**

Designed for petabyte-scale HDFS deployments. Significant operational overhead
for the relatively modest storage needs of a ReportPortal deployment. No
production-ready Helm chart suitable for use as a subchart dependency.

---

## Summary Matrix

| | **SeaweedFS** | **Rook-Ceph** | **GarageHQ** | **Zenko** | **Apache Ozone** |
|---|:---:|:---:|:---:|:---:|:---:|
| Apache 2.0 license | ✅ | ✅ | ❌ AGPL | ✅ | ✅ |
| S3-compatible API | ✅ | ✅ | ✅ | ✅ | ✅ |
| Access key / secret auth | ✅ | ✅ | ✅ | ✅ | ✅ |
| PVC-backed storage | ✅ | ✅ | ✅ | ✅ | ✅ |
| Helm subchart dependency | ✅ | ❌ | ❌ | ❌ | ⚠️ |
| Single-pod demo mode | ✅ `allInOne` | ❌ | ⚠️ | ⚠️ | ❌ |
| Production HA mode | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Active maintenance | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Recommended** | **✅ Yes** | ❌ No | ❌ No | ❌ No | ❌ No |

---

## Existing Production Setup

The `beta` namespace (context `rpp-beta`) does **not** use any in-cluster object
store. It connects directly to **AWS S3** via IRSA (IAM Roles for Service Accounts):

```
DATASTORE_TYPE=s3
DATASTORE_REGION=eu-central-1
DATASTORE_ACCESSKEY=    # empty — IAM role used
DATASTORE_SECRETKEY=    # empty — IAM role used
DATASTORE_DEFAULTBUCKETNAME=rpp-beta-bucket
RP_FEATURE_FLAGS=singleBucket
```

The `perf` namespace was the only environment actively using the MinIO Helm subchart
(`bitnami/minio` v17.0.16, image `bitnamilegacy/minio:2025.7.23`, 50Gi RWO PVC).

---

## Chart Implementation Notes

The ReportPortal Helm chart supports `storage.type: seaweedfs` via two helper
templates in `templates/_helpers.tpl`:

- **`reportportal.datastoreType`** — maps `seaweedfs → minio` for the `DATASTORE_TYPE`
  env var (JClouds `minio` provider speaks plain S3 and works with any S3-compatible
  backend).
- **`reportportal.storageEndpoint`** — builds the full endpoint URL with correct
  default port per type:
  - `seaweedfs` → `http://<release>-seaweedfs-all-in-one.<ns>.svc.cluster.local:8333`
  - `minio` → `http://<release>-minio.<ns>.svc.cluster.local:9000`

Both can be overridden with `storage.endpoint` and `storage.port` for external or
custom deployments.

The mapping is applied consistently across all four storage-consuming services:
`service-api`, `service-jobs`, `service-auto-analyzer`, and `service-authorization`.
