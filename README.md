# [ReportPortal.io](http://ReportPortal.io)

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/reportportal-io)](https://artifacthub.io/packages/search?repo=reportportal-io)
[![Join Slack chat!](https://img.shields.io/badge/slack-join-brightgreen.svg)](https://slack.epmrpp.reportportal.io/)
[![stackoverflow](https://img.shields.io/badge/reportportal-stackoverflow-orange.svg?style=flat)](http://stackoverflow.com/questions/tagged/reportportal)
[![GitHub contributors](https://img.shields.io/badge/contributors-102-blue.svg)](https://reportportal.io/community)
[![Docker Pulls](https://img.shields.io/docker/pulls/reportportal/service-api.svg?maxAge=25920)](https://hub.docker.com/u/reportportal/)
[![License](https://img.shields.io/badge/license-Apache-brightgreen.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Build with Love](https://img.shields.io/badge/build%20with-❤%EF%B8%8F%E2%80%8D-lightgrey.svg)](http://reportportal.io?style=flat)

This repository houses the Helm chart for ReportPortal, a powerful and flexible TestOps service, that provides increased capabilities to speed up results analysis and reporting through the use of built-in analytic features.

## Prerequisites

* Kubernetes v1.26+
* Helm Package Manager v3.4+
* **CloudNativePG operator** — required when using in-cluster PostgreSQL (`postgresql.install: true`). See [CloudNativePG setup](#cloudnativepg-postgresql) below.

## CloudNativePG PostgreSQL

ReportPortal uses [CloudNativePG](https://cloudnative-pg.io/) to run PostgreSQL as a Kubernetes-native cluster (PostgreSQL 17). The CNPG operator must be installed **once per cluster** before deploying ReportPortal with `postgresql.install: true`.

### 1 — Install the CNPG operator

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm install cnpg-operator cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --wait

# Verify CRDs are registered
kubectl get crd clusters.postgresql.cnpg.io
```

### 2 — Deploy ReportPortal with in-cluster PostgreSQL

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set postgresql.install=true
```

> **Non-default release name:** If you use a release name other than `reportportal` (e.g. `helm install rp …`), you must also set the credentials secret name to match:
> ```bash
> --set postgresql.cluster.superuserSecret=rp-cnpg-credentials \
> --set "postgresql.cluster.initdb.secret.name=rp-cnpg-credentials"
> ```

### Use an external / managed database instead

Set `postgresql.install=false` and point `database.endpoint` at your managed database:

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set postgresql.install=false \
  --set database.endpoint=<your-db-host>
```

### Key CloudNativePG values

| Parameter | Default | Description |
|---|---|---|
| `postgresql.install` | `true` | Deploy CNPG cluster (set `false` for external DB) |
| `postgresql.version.postgresql` | `"17"` | PostgreSQL major version |
| `postgresql.cluster.instances` | `1` | Number of PostgreSQL instances |
| `postgresql.cluster.storage.size` | `8Gi` | Persistent volume size per instance |
| `postgresql.cluster.resources` | see values.yaml | CPU/memory requests and limits |
| `postgresql.cluster.superuserSecret` | `reportportal-cnpg-credentials` | Secret name for postgres superuser credentials |
| `database.endpoint` | _(auto)_ | Override to use an external database host |

The Cluster CR and credentials Secret are annotated with `helm.sh/resource-policy: keep`, so they survive `helm uninstall`.

## Documentation

* [General User Manual](https://reportportal.io/docs/)
* [Expert guide and hacks for deploying ReportPortal on Kubernetes](https://reportportal.io/docs/installation-steps/deploy-with-kubernetes/)
* [Quick Start Guide for Google Cloud Platform GKE](https://reportportal.io/docs/installation-steps/deploy-with-kubernetes/QuickStartWithGCPGKE)

## Community / Support

* [**Slack chat**](https://reportportal-slack-auto.herokuapp.com)
* [**Security Advisories**](https://github.com/reportportal/reportportal/blob/master/SECURITY_ADVISORIES.md)
* [GitHub Issues](https://github.com/reportportal/reportportal/issues)
* [Stackoverflow Questions](http://stackoverflow.com/questions/tagged/reportportal)
* [Twitter](http://twitter.com/ReportPortal_io)
* [Facebook](https://www.facebook.com/ReportPortal.io)
* [YouTube Channel](https://www.youtube.com/channel/UCsZxrHqLHPJcrkcgIGRG-cQ)

## License

This Helm chart for ReportPortal is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

### Third-party licenses

This chart includes the following dependencies with their respective licenses:

- **PostgreSQL** (via CloudNativePG) - [PostgreSQL License](https://www.postgresql.org/about/licence/)
- **CloudNativePG operator** - [Apache License 2.0](https://github.com/cloudnative-pg/cloudnative-pg/blob/main/LICENSE)
- **CloudNativePG cluster chart** - [Apache License 2.0](https://github.com/cloudnative-pg/charts/blob/main/LICENSE)
- **RabbitMQ** - [Mozilla Public License 2.0](https://www.rabbitmq.com/mpl.html)
- **OpenSearch** - [Apache License 2.0](https://github.com/opensearch-project/OpenSearch/blob/main/LICENSE.txt)
- **MinIO** - [GNU Affero General Public License v3.0](https://github.com/minio/minio/blob/master/LICENSE) (chart default object storage)
