# CloudNativePG PostgreSQL Setup

ReportPortal uses [CloudNativePG](https://cloudnative-pg.io/) (CNPG) to run PostgreSQL 17 as a Kubernetes-native cluster. This guide covers the two-phase installation: operator setup and ReportPortal deployment.

## Architecture

- The **CNPG operator** (`cnpg/cloudnative-pg`) is installed once per Kubernetes cluster into its own namespace (`cnpg-system`). It owns the `clusters.postgresql.cnpg.io` CRD and manages the lifecycle of all CNPG clusters on the cluster.
- The **CNPG cluster** (`cnpg/cluster`, aliased as `postgresql` in this chart) is installed as part of the ReportPortal Helm release. It creates a `Cluster` custom resource that the operator reconciles into running PostgreSQL pods.
- The **credentials Secret** (`reportportal-cnpg-credentials` by default) is created by this chart and is referenced by the Cluster CR for both the superuser password and the `initdb` bootstrap.

Both the Cluster CR and the credentials Secret carry `helm.sh/resource-policy: keep`, so they are **not deleted** on `helm uninstall`.

## Phase 1 — Install the CNPG operator

The operator must be installed **before** `helm install reportportal`. It only needs to be done once per cluster.

> **Note:** The operator is intentionally not bundled as a Helm subchart dependency.
> Bundling it causes Helm ownership conflicts when the operator is already present
> on the cluster, since its CRDs and webhook configurations are cluster-scoped resources
> that cannot be claimed by multiple Helm releases.

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm install cnpg-operator cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --wait

# Confirm CRDs are registered
kubectl get crd clusters.postgresql.cnpg.io
```

## Phase 2 — Deploy ReportPortal

### Default install (release name: `reportportal`)

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set postgresql.install=true
```

The chart creates:
- A `kubernetes.io/basic-auth` Secret named `reportportal-cnpg-credentials` with the credentials from `database.user` / `database.password`.
- A CNPG `Cluster` CR named `reportportal-postgresql` with PostgreSQL 17, 1 instance, and 8 Gi storage.
- A read-write service at `reportportal-postgresql-rw.reportportal.svc.cluster.local:5432`.

### Custom release name (e.g. `rp`)

When the release name differs from `reportportal`, the credentials secret name must be overridden to match what the chart template will create:

```bash
helm install rp reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set postgresql.install=true \
  --set postgresql.cluster.superuserSecret=rp-cnpg-credentials \
  --set "postgresql.cluster.initdb.secret.name=rp-cnpg-credentials"
```

The chart creates:
- A Secret named `rp-cnpg-credentials`.
- A CNPG Cluster CR named `rp-postgresql`.
- A read-write service at `rp-postgresql-rw.reportportal.svc.cluster.local:5432`.

## Use an external / managed database

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
| `postgresql.install` | `true` | Deploy CNPG cluster. Set `false` for external DB. |
| `postgresql.version.postgresql` | `"17"` | PostgreSQL major version |
| `postgresql.cluster.instances` | `1` | Number of PostgreSQL instances |
| `postgresql.cluster.storage.size` | `8Gi` | Persistent volume size per instance |
| `postgresql.cluster.resources.requests.cpu` | `100m` | CPU request per instance |
| `postgresql.cluster.resources.requests.memory` | `256Mi` | Memory request per instance |
| `postgresql.cluster.resources.limits.cpu` | `500m` | CPU limit per instance |
| `postgresql.cluster.resources.limits.memory` | `512Mi` | Memory limit per instance |
| `postgresql.cluster.superuserSecret` | `reportportal-cnpg-credentials` | Credentials secret name (must match `initdb.secret.name`) |
| `postgresql.cluster.initdb.secret.name` | `reportportal-cnpg-credentials` | Same secret, used during cluster bootstrap |
| `database.endpoint` | _(auto-computed)_ | Override to point at an external database |
| `database.user` | `postgres` | Database username written into the credentials secret |
| `database.password` | `rppassword` | Database password written into the credentials secret |
| `database.dbName` | `reportportal` | Database name created during `initdb` |
| `database.port` | `5432` | Database port |

## Upgrades

`helm upgrade` updates the Cluster CR spec (instances, resources, storage class). The CNPG operator handles rolling updates automatically. Storage size can only be increased, not decreased.

The credentials Secret and Cluster CR are preserved across `helm uninstall` due to `helm.sh/resource-policy: keep`. To fully remove the PostgreSQL cluster, delete them manually after uninstalling:

```bash
kubectl delete cluster reportportal-postgresql -n reportportal
kubectl delete secret reportportal-cnpg-credentials -n reportportal
```

## References

- [CloudNativePG documentation](https://cloudnative-pg.io/documentation/)
- [CNPG cluster chart values](https://github.com/cloudnative-pg/charts/blob/main/charts/cluster/values.yaml)
- [CNPG operator chart](https://github.com/cloudnative-pg/charts/tree/main/charts/cloudnative-pg)


