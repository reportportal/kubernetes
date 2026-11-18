# Migration from ReportPortal 26.0 to 26.1

<img alt="Release 16 1 Thumbnails" src="https://github.com/user-attachments/assets/e6c7f45f-a104-453b-8d0f-f31551bbc330" />

This guide is for administrators moving a Kubernetes installation from the 26.0 chart to the 26.1 chart. Read [Breaking changes](#breaking-changes) first. The chart does not copy objects and does not rewrite paths in PostgreSQL.

## Contents

- [Pick your path](#pick-your-path)
- [Breaking changes](#breaking-changes)
- [What changed](#what-changed)
  - [Where objects live](#where-objects-live)
- [Prerequisite: update to 26.10.26 first](#prerequisite-update-to-261026-first)
- [Option A: Bundled MinIO to bundled SeaweedFS](#option-a-bundled-minio-to-bundled-seaweedfs)
- [Option B: Amazon S3](#option-b-amazon-s3)
- [Option C: Other S3-compatible storage](#option-c-other-s3-compatible-storage)
- [Safety and rollback](#safety-and-rollback)
- [Known limits](#known-limits)

## Pick your path

First check the chart version of your 26.0 release with `helm list -n <namespace>`. If it is older than `26.8.12`, do the [prerequisite](#prerequisite-update-to-261026-first) first. Then pick the option that matches the storage you run today:

| Your 26.0 install | What you do | Where |
|--|--|--|
| Chart older than `26.8.12` (Bitnami PostgreSQL and RabbitMQ, OpenSearch 2) | Update to `26.10.26` with the 26.0.x guide, then continue with one of the options below | [Prerequisite](#prerequisite-update-to-261026-first) |
| Bundled MinIO (`storage.type: minio`, `multi`) | Uninstall 26.0, run MinIO on the kept volume, install 26.1 with bundled SeaweedFS, and copy the buckets into `rp-bucket` | [Option A](#option-a-bundled-minio-to-bundled-seaweedfs) |
| Amazon S3 (`storage.type: s3`, `single`) | Change `s3` to `aws-s3`, keep `single` and the same bucket. No copy | [Option B](#option-b-amazon-s3) |
| External MinIO, Ceph, or another S3 API that you run yourself | Change `minio` or `s3` to `s3-compatible`. Copy inside the store only for `multi` | [Option C](#option-c-other-s3-compatible-storage) |

Day-to-day settings after the move are in [S3-Compatible Object Storage](https://github.com/reportportal/kubernetes/blob/master/docs/s3-compatible-storage.md). The Amazon S3 role, bucket, and IRSA annotation are in [S3 Storage on EKS](https://github.com/reportportal/kubernetes/blob/master/docs/s3-storage-eks.md).

## Breaking changes

Read this section before you change anything. Each item can make existing files unreachable or stop the release from upgrading.

1. **Bundled MinIO is removed.** The 26.1 chart has no `minio` sub-chart. `helm upgrade` deletes the MinIO Deployment, Service, and Secret of the release. The volume (PVC `<release>-minio`) is kept, but nothing serves it any more. A `helm upgrade` with default values also installs an empty bundled SeaweedFS and points the services at it. Do not run a plain `helm upgrade`. Follow [Option A](#option-a-bundled-minio-to-bundled-seaweedfs).
2. **The `multi` object layout changed.** In 26.0, `multi` means one bucket per project (`prj-<projectId>`). In 26.1, `multi` keeps the same names but as folders inside the default bucket (`rp-bucket/prj-<projectId>/…`). 26.1 does not read the 26.0 buckets. Existing data must be copied into the new layout. See [What changed](#what-changed).
3. **`storage.type: minio` and `storage.type: s3` are rejected.** Use `s3-compatible` (MinIO, SeaweedFS, and other S3 APIs) or `aws-s3`. The chart fails at render time with a message that names the replacement.
4. **The default `storage.secretkey` changed from `miniopassword` to `rppassword`.** The new bundled SeaweedFS can use the new default keys. If you set your own `storage.accesskey` and `storage.secretkey`, also set `seaweedfs.s3.credentials.admin.accessKey` and `secretKey`. Otherwise the services fail with `SignatureDoesNotMatch`.
5. **`storage.endpoint` must be a host name.** A value that starts with `http://` or `https://` fails at render time. Use `storage.ssl` and `storage.port` for the scheme and port.
6. **The superadmin login changes.** In 26.1 the built-in `superadmin` account is renamed to `admin@reportportal.internal`. Sign in with the new name. Scripts that use `superadmin` as the login must change too.
7. **Start from the latest 26.0 chart (`26.10.26`).** Charts older than `26.8.12` use Bitnami PostgreSQL and RabbitMQ. They cannot move to 26.1 directly (an upgrade fails with `updates to statefulset spec ... are forbidden`). Upgrade to `26.10.26` first. See the [prerequisite](#prerequisite-update-to-261026-first).

Compared releases:

| | 26.0 chart | 26.1 chart |
|--|------------|------------|
| Chart | `26.10.26` (`appVersion` 26.0.7) | `26.11.x` (`appVersion` 26.1) |
| Service images | `service-api`, `service-jobs` 5.15.x | `6.0.0` |
| Bundled object storage | Bitnami MinIO, `minio.install: true` | SeaweedFS 4.53.0, `seaweedfs.install: true` |
| `storage.type` | `minio` (also `s3`, `filesystem`) | `s3-compatible` (also `aws-s3`, `filesystem`) |
| `storage.bucket.type` | `multi` | `multi` (default), but the layout changed. `single` is also supported |
| Default secret key | `miniopassword` | `rppassword` |

## What changed

`service-api`, `service-jobs`, and `service-auto-analyzer` use [Apache OpenDAL](https://opendal.apache.org/) and accept only `s3-compatible`, `aws-s3`, and `filesystem`.

| 26.0 value | 26.1 value |
|------------|------------|
| `storage.type: minio` | `storage.type: s3-compatible` |
| `storage.type: s3` | `storage.type: aws-s3` |
| `storage.type: filesystem` | unchanged |

The standalone UAT (authorization) service is removed in 26.1. `service-api` takes over its work, so the release has no `-uat` Deployment and the token endpoint moves from `/uat/sso/oauth/token` to `/api/sso/oauth/token`. See step 9 of [Option A](#option-a-bundled-minio-to-bundled-seaweedfs).

`storage.endpoint` is a host name. The chart adds `http://` or `https://` from `storage.ssl`, and adds `storage.port` only when you set it. An empty endpoint with `seaweedfs.install: true` points at `<release>-seaweedfs-all-in-one.<namespace>.svc:8333`.

### Where objects live

In 26.1 the API opens one bucket, `storage.bucket.bucketDefaultName`. In `multi` mode the name of the old bucket becomes the first folder inside it. The database stores the same paths in both releases, so no SQL is needed after the copy.

| Data | 26.0 (bucket / key) | 26.1 `multi` (bucket / key) |
|------|---------------------|------------------------------|
| Attachments of project 1 | `prj-1` / `2026-11/<launch>/<file>` | `rp-bucket` / `prj-1/2026-11/<launch>/<file>` |
| Integration salt | `prj-keystore` / `secret-integration-salt` | `rp-bucket` / `prj-keystore/secret-integration-salt` |
| User photos | `prj-users` / `<login>` | `rp-bucket` / `prj-users/<login>` |
| Plugins | `rp-bucket` / `<plugin>.jar` | `rp-bucket` / `rp-bucket/<plugin>.jar` |

Every 26.0 bucket becomes a folder of the same name. That includes the default bucket itself, which holds the plugins.

The database never stores a bucket. `attachment.file_id` holds the base64 of the relative path, for example `1/2026-11/<launch>/<file>`. 26.0 and 26.1 build that path the same way. Only the step from path to storage changed:

| Mode | Path in the database | 26.0 storage | 26.1 storage |
|------|----------------------|--------------|--------------|
| `multi` | `1/2026-11/<launch>/<file>` | bucket `prj-1`, key `2026-11/<launch>/<file>` | bucket `rp-bucket`, key `prj-1/2026-11/<launch>/<file>` |
| `single` | `project-data/1/2026-11/<launch>/<file>` | bucket `rp-bucket`, same key | the same, no change |

`bucketMultiPrefix` is only the folder prefix. It does not have to be `prj-`, but it must be the value that 26.0 used.

In `single` mode new attachment keys are:

```text
<bucketDefaultName>/project-data/<projectId>/<yyyy-M>/<launchUuid>/<file>
```

A 26.0 install that already used `storage.bucket.type: single` keeps its layout. It needs no object copy.

The analyzer always uses one bucket. The 26.1 chart stores models at:

```text
<bucketDefaultName>/<analyzerPath>/<bucketMultiPrefix><projectId>/
# default: rp-bucket/analyzer/prj-<projectId>/
```

The chart does not move existing model files.

The integration salt is the one object you must not lose. If the API does not find it, it generates a new one and existing integration secrets in the database can no longer be decrypted. In `multi` mode it is read from `<bucketMultiPrefix><bucketMultiSaltName>/secret-integration-salt` (default `prj-keystore/secret-integration-salt`) in the default bucket.


## Prerequisite: update to 26.10.26 first

Update to chart `26.10.26` (ReportPortal 26.0.7) before you start. Charts older than `26.8.12` use Bitnami PostgreSQL and RabbitMQ and OpenSearch 2. They need a dump and restore of PostgreSQL, so they cannot move to 26.1 directly. Follow the [Migration to 26.0.x](https://github.com/reportportal/kubernetes/wiki/Migration-v26) guide. It has downtime.

Check your version with `helm list -n <namespace>`. If the chart is `26.8.12` or newer, go to your option.

## Option A: Bundled MinIO to bundled SeaweedFS

The procedure has downtime. You uninstall the 26.0 release, run MinIO from the kept volume only as the copy source, install 26.1 with the bundled SeaweedFS, and copy the objects into it.

The services start on an empty SeaweedFS in step 6. On first start the API creates a new integration salt and uploads its bundled plugins. The copy in step 7 overwrites them with your 26.0 objects, and the restart in step 8 makes the API read the old salt. Nobody should use ReportPortal between step 6 and step 8.

Replace `<release>`, `<namespace>`, `<access-key>`, and `<secret-key>` in the commands. The keys are your 26.0 `storage.accesskey` and `storage.secretkey` (defaults `rpuser` and `miniopassword`). They are used for the temporary MinIO only. SeaweedFS is new and gets its own keys in step 5.

1. **Back up** the PostgreSQL database and the MinIO volume.

2. **Save your 26.0 settings and find the names.** The uninstall in step 3 removes the release, so save its values first.

```bash
helm get values <release> -n <namespace> --all > values-26.0.yaml
kubectl get pvc -n <namespace>
kubectl get deploy <release>-minio -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].image}'
```

The second command lists the volumes. The MinIO volume is `<release>-minio`. The third command prints the MinIO image tag that you reuse in step 4.

3. **Uninstall ReportPortal 26.0.**

```bash
helm uninstall <release> -n <namespace>
kubectl get pvc -n <namespace>
```

Helm keeps the volumes of MinIO, PostgreSQL, RabbitMQ, and OpenSearch. Confirm that all of them are still listed. Your attachments and database stay on these volumes.

4. **Run MinIO on the kept volume.** It is the same Bitnami chart (`minio` 17.0.21) as in 26.0, in its own release. `persistence.existingClaim` is the MinIO volume from step 2. Use the image tag from step 2 and your 26.0 root credentials (`rpuser` and `miniopassword` unless you changed them).

```bash
helm install minio oci://registry-1.docker.io/bitnamicharts/minio --version 17.0.21 -n <namespace> \
  --set global.security.allowInsecureImages=true \
  --set image.repository=bitnamilegacy/minio --set image.tag=<minio-image-tag> \
  --set clientImage.repository=bitnamilegacy/minio-client --set clientImage.tag=2025.7.21-debian-12-r2 \
  --set auth.rootUser=<access-key> --set auth.rootPassword=<secret-key> \
  --set persistence.existingClaim=<release>-minio \
  --set console.enabled=false

kubectl rollout status deployment/minio -n <namespace>
```

5. **Prepare the 26.1 values file.** Start from `values-26.0.yaml` and change only the storage settings:

   - Replace `storage.type: minio` (or `s3`) with `s3-compatible`.
   - Delete the whole `minio:` block.
   - Keep `bucketDefaultName`, `bucketMultiPrefix`, `bucketMultiPostfix`, and `bucketMultiSaltName` as they were in 26.0. `multi` is the default in 26.1, so `type: multi` is optional.
   - Do not set `storage.endpoint` or `storage.port`. Without them the chart uses its own SeaweedFS.

```yaml
storage:
  type: s3-compatible
  # SeaweedFS is new, so it can use new keys. These are the chart defaults.
  accesskey: rpuser
  secretkey: rppassword
  bucket:
    type: multi
    bucketDefaultName: rp-bucket
    bucketMultiPrefix: prj-

seaweedfs:
  install: true
  allInOne:
    data:
      type: persistentVolumeClaim
      # Adjust the volume size to suit your needs
      size: 10Gi
```

If you choose your own keys, set them in `storage.accesskey` and `storage.secretkey` and also in `seaweedfs.s3.credentials.admin.accessKey` and `secretKey`. The chart ties the two only for the default keys. Without the second pair the API fails with `SignatureDoesNotMatch`.

6. **Install ReportPortal 26.1.** The release was uninstalled in step 3, so this is an install, not an upgrade.

```bash
helm install <release> ./reportportal -n <namespace> -f <your-values>.yaml
kubectl rollout status deployment/<release>-seaweedfs-all-in-one -n <namespace>
```

The migrations run on your kept PostgreSQL volume.

7. **Copy the data.** Start a shell with the MinIO client. `<seaweedfs-access-key>` and `<seaweedfs-secret-key>` are the keys from step 5. If a secret key contains special characters, URL-encode it in the `MC_HOST_` values.

```bash
kubectl run mc -it --rm --restart=Never -n <namespace> \
  --image=bitnamilegacy/minio-client:2025.7.21-debian-12-r2 \
  --env="MC_HOST_minio=http://<access-key>:<secret-key>@minio.<namespace>.svc.cluster.local:9000" \
  --env="MC_HOST_seaweed=http://<seaweedfs-access-key>:<seaweedfs-secret-key>@<release>-seaweedfs-all-in-one.<namespace>.svc.cluster.local:8333" \
  --command -- sh
```

Run these three commands in that shell:

```bash
mc mb --ignore-existing seaweed/rp-bucket
mc mirror --overwrite --preserve minio/ seaweed/rp-bucket/
mc cp --recursive minio/prj-keystore/ seaweed/rp-bucket/prj-keystore/
```

`mc mirror` copies every MinIO bucket into a folder of the same name in `rp-bucket`. It needs no list of buckets. That covers the project data (`prj-*`), the user photos (`prj-users`), and the plugins (`rp-bucket`, which become `rp-bucket/rp-bucket/`).

The third command is the salt. `mc mirror --overwrite` does not replace it: the API has already written a new salt of the same size, and `mc mirror` skips that object. `mc cp` writes the 26.0 salt over it. Without this copy the integration secrets in the database cannot be decrypted.

If your 26.0 `bucketDefaultName` is not `rp-bucket`, use your name instead of `rp-bucket`.

If 26.0 already used `storage.bucket.type: single`, set `type: single` in step 5 and copy only the data bucket, keeping the keys: `mc mirror --overwrite --preserve minio/rp-bucket/ seaweed/rp-bucket/`.

Check the result. You see one folder per MinIO bucket, and the salt in `prj-keystore`:

```bash
mc ls --recursive seaweed/rp-bucket
mc stat minio/prj-keystore/secret-integration-salt
mc stat seaweed/rp-bucket/prj-keystore/secret-integration-salt
```

The `ETag` of the two salt files must be the same.

8. **Restart the API and Jobs.** This is required. The API reads the integration salt once, at start, so it must be restarted to use the copied salt. Restarting Jobs is harmless.

```bash
kubectl rollout restart deployment <release>-reportportal-api <release>-reportportal-jobs -n <namespace>
kubectl rollout status deployment/<release>-reportportal-api -n <namespace>
```

9. **Sign in through the API.** In 26.0 the login ran in a separate `<release>-reportportal-uat` Deployment. 26.1 removes it, and `service-api` now does that work: it issues tokens and manages sessions. Confirm:
   - `kubectl get deploy -n <namespace>` lists no `-uat` Deployment.
   - The superadmin signs in to the UI. The built-in account was renamed to `admin@reportportal.internal` in 26.1, so use that name. Use the password you had in 26.0.
   - Scripts and clients that request tokens must change the endpoint. In 26.0 it was `/uat/sso/oauth/token`. In 26.1 it is `/api/sso/oauth/token`, with client `ui:uiman`.

10. **Check.** Wait until the API pod is Ready, then confirm:
   - an attachment that was uploaded on 26.0 opens
   - the connection test of an existing integration works. This confirms that the old salt is in use
   - the plugins page loads. The copy leaves the old and the new plugin jar versions side by side
   - the analyzer works. The chart does not move analyzer models, and they can be retrained

11. **Clean up later.** The `minio` release and its volume stay as the rollback copy. After you are sure, remove the release with `helm uninstall minio -n <namespace>`. The volume `<release>-minio` is kept until you delete it.

## Option B: Amazon S3

Use this when 26.0 used `storage.type: s3` with `storage.bucket.type: single`. The bucket and the layout stay the same, so there is no copy, no MinIO, and no uninstall. Creating the bucket, the IAM role, and the IRSA annotation is described in [S3 Storage on EKS](https://github.com/reportportal/kubernetes/blob/master/docs/s3-storage-eks.md). Keep the role you already use.

1. **Back up** the PostgreSQL database.

2. **Save your 26.0 settings.**

```bash
helm get values <release> -n <namespace> --all > values-26.0.yaml
```

3. **Change the storage type.** In `values-26.0.yaml`, make only these changes:
   - `storage.type: s3` becomes `storage.type: aws-s3`.
   - Keep `storage.region`, `storage.bucket.type: single`, and `storage.bucket.bucketDefaultName` as they were.
   - Keep `storage.accesskey` and `storage.secretkey` for static keys, or leave them empty for IRSA.
   - Set `seaweedfs.install: false`, so the chart does not install SeaweedFS.

Save the result as `values-26.1-s3.yaml`. Replace the region, the bucket name, and the keys with the values from `values-26.0.yaml`. Leave the keys empty when 26.0 used an IAM role (IRSA).

```yaml
global:
  serviceAccount:
    create: true
    name: reportportal
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::<AWS_ACCOUNT_ID>:role/<MY_S3_ROLE>"

storage:
  type: aws-s3
  region: us-east-1
  accesskey: ""
  secretkey: ""
  bucket:
    type: single
    bucketDefaultName: my-rp-bucket

seaweedfs:
  install: false
```

4. **Upgrade ReportPortal.**

```bash
helm upgrade <release> ./reportportal -n <namespace> -f values-26.1-s3.yaml
```

5. **Check.** Wait until the API pod is Ready, then confirm that an attachment from 26.0 opens, and that the connection test of an existing integration works.

## Option C: Other S3-compatible storage

Use this when you run the object store yourself and keep it: external MinIO, Ceph RGW, or another S3 API (26.0 `storage.type: minio`, or `s3` with a custom endpoint). The store stays where it is. You change the values, and for `multi` you copy inside the store. Do not install SeaweedFS.

1. **Back up** the PostgreSQL database, and save your settings.

```bash
helm get values <release> -n <namespace> --all > values-26.0.yaml
```

2. **Prepare the 26.1 values file.** In `values-26.0.yaml` set the type, the endpoint, and `seaweedfs.install: false`, and delete the `minio:` block. Keep the keys and bucket settings.

```yaml
storage:
  type: s3-compatible
  endpoint: "s3.example.com"   # host name only, no http:// or https://
  ssl: true
  port: 443
  region: ""
  accesskey: <access-key>
  secretkey: <secret-key>
  bucket:
    type: multi                # the type you used in 26.0
    bucketDefaultName: rp-bucket
    bucketMultiPrefix: prj-

seaweedfs:
  install: false
```

3. **Only for `multi`: stop ReportPortal and copy inside the store.** In 26.0 `multi` has one bucket per project. 26.1 reads them as folders of the default bucket. Stop the services so nothing writes during the copy:

```bash
kubectl scale deployment <release>-reportportal-api <release>-reportportal-jobs <release>-reportportal-uat -n <namespace> --replicas=0
kubectl scale statefulset <release>-reportportal-analyzer -n <namespace> --replicas=0
```

   Start a shell with the MinIO client (it works with any S3 API). Use `https` and the right port in the URL when the store needs them.

```bash
kubectl run mc -it --rm --restart=Never -n <namespace> \
  --image=bitnamilegacy/minio-client:2025.7.21-debian-12-r2 \
  --env="MC_HOST_store=https://<access-key>:<secret-key>@<endpoint>:<port>" \
  --command -- sh
```

   Run these two commands in that shell. The first moves the plugins that already sit in `rp-bucket`. The second copies every other bucket into a folder of the same name. The old buckets stay as the rollback copy.

```bash
mc mirror --preserve --exclude "rp-bucket/*" store/rp-bucket store/rp-bucket/rp-bucket
mc mirror --preserve --exclude "rp-bucket/*" store/ store/rp-bucket/
```

   If 26.0 used `single`, skip this step. The layout does not change.

4. **Upgrade ReportPortal.** `helm upgrade` removes the `-uat` Deployment and restores the replicas of the other services.

```bash
helm upgrade <release> ./reportportal -n <namespace> -f values-26.1-s3-compatible.yaml
```

5. **Check.** Wait until the API pod is Ready. Confirm that an attachment from 26.0 opens, and that the connection test of an existing integration works. For `multi`, the salt must exist at `rp-bucket/prj-keystore/secret-integration-salt`: `mc stat store/rp-bucket/prj-keystore/secret-integration-salt`.

## Safety and rollback

This section covers Option A.

- Back up PostgreSQL and the MinIO volume before step 3.
- The copy only reads MinIO. The MinIO volume and its buckets stay untouched, so they are the rollback copy.
- The database is not changed by the copy. The migrations of 26.1 run in step 6.
- To roll back, uninstall the 26.1 release, restore the PostgreSQL backup, and install the 26.0 chart with `values-26.0.yaml`. The 26.0 chart brings its own MinIO, so uninstall the `minio` release first and keep the volume.

## Known limits

- The chart does not copy objects and does not rewrite `attachment.file_id`. The copy in this guide is the only data move.
- In `multi` mode `service-api` stores project data as folders in the default bucket, while `service-jobs` addresses a bucket per project (`prj-<projectId>`). Clean-up work done by Jobs (for example launch retention and project deletion) may therefore not remove the files that the API stored. Monitor storage growth and plan manual clean-up.
- This guide keeps `multi`. A later switch from `multi` to `single` is not automatic. `single` reads the database path as it is and writes new files under `project-data/`, so objects must be moved (`prj-<id>/` to `<id>/` at the bucket root, `prj-users/` to `users/`, and the salt to `integration-secrets/`). Do not change `storage.bucket.type` on a running installation without that move.
- The analyzer looks for models at `<bucketDefaultName>/analyzer/prj-<projectId>/` after the upgrade. Confirm one model; the chart does not move it.
- 26.1 renames the built-in users in the database (for example `superadmin` becomes `admin@reportportal.internal`). Sign in with the new name.
