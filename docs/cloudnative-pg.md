# CloudNativePG PostgreSQL Setup

ReportPortal uses [CloudNativePG](https://cloudnative-pg.io/) (CNPG) to run PostgreSQL 17 as a Kubernetes-native cluster. The CNPG operator is bundled as a Helm subchart — **no pre-install step is required**.

## Architecture

- The **CNPG operator** (`cnpg/cloudnative-pg` v0.23.0) is installed as a subchart of the ReportPortal release. It registers the `postgresql.cnpg.io` CRDs, deploys the controller, and manages the lifecycle of all CNPG clusters in the namespace.
- The **Cluster CR** (`postgresql.cnpg.io/v1`) is a hand-rolled template in this chart (`templates/cloudnative-pg/cluster.yaml`). It defines the PostgreSQL instance count, storage, and bootstrap credentials.
- The **credentials Secret** (`<release>-cnpg-credentials`) is created by this chart and referenced by the Cluster CR for both the superuser password and the `initdb` bootstrap.

Both the Cluster CR and the credentials Secret carry `helm.sh/resource-policy: keep`, so they are **not deleted** on `helm uninstall`.

### How CRDs are managed

The CNPG operator chart stores its CRDs in `templates/crds/crds.yaml` (a Helm template, not in the `crds/` directory). To ensure CRDs are registered before the Cluster CR template is applied, this chart bundles a copy of the CNPG CRDs in `reportportal/crds/cnpg-crds.yaml`. Helm installs files in `crds/` before processing any templates, which eliminates the CRD registration race condition.

> **Maintenance note:** When the `cloudnative-pg` version is bumped in `Chart.yaml`, the bundled CRD file must also be updated. Extract the new CRDs with:
> ```bash
> tar -xOf reportportal/charts/cloudnative-pg-<new-version>.tgz \
>   cloudnative-pg/templates/crds/crds.yaml \
>   | tail -n +2 | head -n -1 \
>   > reportportal/crds/cnpg-crds.yaml
> ```
> The `tail -n +2 | head -n -1` strips the Helm `{{- if }}` / `{{- end }}` wrapper. Commit the updated file alongside the `Chart.yaml` version bump.

## Install

### Default install (CNPG enabled)

No pre-requisites. A single command installs the operator, creates the PostgreSQL cluster, and deploys all ReportPortal services:

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set uat.superadminInitPasswd.password=<your-password>
```

`postgresql.install` defaults to `true`, so the CNPG operator and Cluster CR are included automatically.

The chart creates:
- A `kubernetes.io/basic-auth` Secret named `reportportal-cnpg-credentials` with the credentials from `database.user` / `database.password`.
- A CNPG `Cluster` CR named `reportportal-postgresql` with PostgreSQL 17, 1 instance, and 8 Gi storage.
- A read-write service at `reportportal-postgresql-rw.reportportal.svc.cluster.local:5432`.

### Custom release name (e.g. `rp`)

Resource names are derived automatically from the release name — no extra flags needed:

```bash
helm install rp reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set uat.superadminInitPasswd.password=<your-password>
```

The chart creates:
- A Secret named `rp-cnpg-credentials`.
- A CNPG Cluster CR named `rp-postgresql`.
- A read-write service at `rp-postgresql-rw.reportportal.svc.cluster.local:5432`.

### Custom Cluster CR name

If you need a Cluster CR name that does not follow the `<release>-postgresql` default (for example, when adopting an existing CNPG cluster or migrating from a previous install), use `postgresql.clusterNameOverride`:

```bash
helm install rp reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set postgresql.clusterNameOverride=my-existing-cluster
```

The `databaseEndpoint` helper resolves to `<clusterNameOverride>-rw.<namespace>.svc.cluster.local`.

### Use an external / managed database

Set `postgresql.install=false` and point `database.endpoint` at your existing PostgreSQL host:

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set postgresql.install=false \
  --set database.endpoint=<your-db-host>
```

## Key values

| Parameter | Default | Description |
|---|---|---|
| `postgresql.install` | `true` | Deploy CNPG operator + cluster. Set `false` for external DB. |
| `postgresql.version` | `"17"` | PostgreSQL major version — drives `imageName` in the Cluster CR. |
| `postgresql.instances` | `1` | Number of PostgreSQL instances in the cluster. |
| `postgresql.storage.size` | `8Gi` | Persistent volume size per instance. |
| `postgresql.storage.storageClass` | `""` | Storage class name. Empty uses the cluster default. |
| `postgresql.resources.requests.cpu` | `100m` | CPU request per instance. |
| `postgresql.resources.requests.memory` | `256Mi` | Memory request per instance. |
| `postgresql.resources.limits.cpu` | `500m` | CPU limit per instance. |
| `postgresql.resources.limits.memory` | `512Mi` | Memory limit per instance. |
| `postgresql.clusterNameOverride` | _(not set)_ | Override the Cluster CR name. See [Custom Cluster CR name](#custom-cluster-cr-name). |
| `database.endpoint` | _(auto-computed)_ | Override to point at an external database. |
| `database.user` | `postgres` | Database username written into the credentials secret. |
| `database.password` | `rppassword` | Database password written into the credentials secret. |
| `database.dbName` | `reportportal` | Database name created during `initdb`. |
| `database.port` | `5432` | Database port. |

## Upgrades

`helm upgrade` updates the Cluster CR spec (instances, resources, storage class). The CNPG operator handles rolling updates automatically. Storage size can only be increased, not decreased.

## Data safety and manual cleanup

The credentials Secret and Cluster CR are annotated with `helm.sh/resource-policy: keep`, so they are **preserved on `helm uninstall`**. This protects persistent data from accidental deletion.

To fully remove the PostgreSQL cluster and all its data after uninstalling the Helm release:

```bash
# Replace <release> and <namespace> with your values
kubectl delete cluster <release>-postgresql -n <namespace>
kubectl delete secret <release>-cnpg-credentials -n <namespace>

# PVCs are not deleted automatically by CNPG — remove them explicitly:
kubectl delete pvc -l cnpg.io/cluster=<release>-postgresql -n <namespace>
```

> **Warning:** Deleting the Cluster CR triggers immediate pod and PVC removal by the CNPG operator (unless `pvcReclaimPolicy: retain` is set). Ensure you have a backup before proceeding.

## Prior operator installations

If a CNPG operator was previously installed as a **separate Helm release** (e.g. `helm install cnpg-operator cnpg/cloudnative-pg --namespace cnpg-system`), uninstall it first before deploying this chart with `postgresql.install: true`. The bundled CRDs in `reportportal/crds/` are skipped automatically if the CRDs already exist, but a separate operator release will conflict with this chart's subchart operator over cluster-scoped webhook and RBAC resources.

```bash
helm uninstall cnpg-operator -n cnpg-system
```

## References

- [CloudNativePG documentation](https://cloudnative-pg.io/documentation/)
- [CNPG operator chart](https://github.com/cloudnative-pg/charts/tree/main/charts/cloudnative-pg)
- [CNPG operator chart values](https://github.com/cloudnative-pg/charts/blob/main/charts/cloudnative-pg/values.yaml)
