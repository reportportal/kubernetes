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

## CloudNativePG PostgreSQL

ReportPortal uses [CloudNativePG](https://cloudnative-pg.io/) to run PostgreSQL 17 as a Kubernetes-native cluster. The CNPG operator is bundled as a Helm subchart — no pre-install step is needed.

### Single-command install with in-cluster PostgreSQL

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set uat.superadminInitPasswd.password=<your-password>
```

`postgresql.install` defaults to `true`. The operator, Cluster CR, and all ReportPortal services are deployed in a single command. Resource names are derived automatically from the release name — no extra flags required for custom release names.

### Use an external / managed database instead

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
| `postgresql.install` | `true` | Deploy CNPG operator + cluster (set `false` for external DB) |
| `postgresql.version` | `"17"` | PostgreSQL major version |
| `postgresql.instances` | `1` | Number of PostgreSQL instances |
| `postgresql.storage.size` | `8Gi` | Persistent volume size per instance |
| `postgresql.resources` | see values.yaml | CPU/memory requests and limits per instance |
| `postgresql.clusterNameOverride` | _(auto)_ | Override the Cluster CR name (e.g. to adopt an existing cluster) |
| `database.endpoint` | _(auto)_ | Override to use an external database host |

The Cluster CR and credentials Secret are annotated with `helm.sh/resource-policy: keep`, so they survive `helm uninstall`. See [docs/cloudnative-pg.md](docs/cloudnative-pg.md) for full details including manual cleanup instructions.

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
- **RabbitMQ** - [Mozilla Public License 2.0](https://www.rabbitmq.com/mpl.html)
- **OpenSearch** - [Apache License 2.0](https://github.com/opensearch-project/OpenSearch/blob/main/LICENSE.txt)
- **MinIO** - [GNU Affero General Public License v3.0](https://github.com/minio/minio/blob/master/LICENSE) (chart default object storage)
