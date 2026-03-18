# [ReportPortal.io](http://ReportPortal.io)

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/reportportal-io)](https://artifacthub.io/packages/search?repo=reportportal-io)
[![Join Slack chat!](https://img.shields.io/badge/slack-join-brightgreen.svg)](https://slack.epmrpp.reportportal.io/)
[![stackoverflow](https://img.shields.io/badge/reportportal-stackoverflow-orange.svg?style=flat)](http://stackoverflow.com/questions/tagged/reportportal)
[![GitHub contributors](https://img.shields.io/badge/contributors-102-blue.svg)](https://reportportal.io/community)
[![Docker Pulls](https://img.shields.io/docker/pulls/reportportal/service-api.svg?maxAge=25920)](https://hub.docker.com/u/reportportal/)
[![License](https://img.shields.io/badge/license-Apache-brightgreen.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Build with Love](https://img.shields.io/badge/build%20with-❤%EF%B8%8F%E2%80%8D-lightgrey.svg)](http://reportportal.io?style=flat)

ReportPortal is a TestOps service, that provides increased capabilities to speed up results analysis and reporting through the use of built-in analytic features.

## Prerequisites

> **Note:** The minimal requirements for a ReportPortal 1-node solution are 2 CPUs and 6Gi of memory

* Kubernetes v1.26+
* Helm Package Manager v3.4+

## Installing the Chart

Add the official ReportPortal Helm Chart repository:

```bash
helm repo add reportportal https://k8s.reportportal.io/ && helm repo update reportportal
```

Install the chart:

```bash
helm install my-release --set uat.superadminInitPasswd.password="MyPassword" reportportal/reportportal
```

> **Note:** Upon the initial installation and the first login of the SuperAdmin, they will be required to create a unique initial password, distinct from the default password provided in the ReportPortal installation documentation. Failure to do so will result in the Auth service not starting

## Uninstalling the Chart

```bash
helm uninstall my-release 
```

## Configuration

### Install the chart with dependencies

ReportPortal relies on several essential dependencies, without which it cannot function properly. It is feasible to substitute these dependencies with available On-Premise or Cloud alternatives.

The following table lists the configurable parameters of the chart and their default values

|Parameter|Description|Default|
|-|-|-|
|`postgresql.install`|Allow PostgreSQL Bitnami Helm Chart to be installed as a dependency|`true`|
|`rabbitmq.install`|Allow RabbitmQ Helm Bitnami Chart to be installed as a dependency|`true`|
|`opensearch.install`|Allow Open Search Helm Chart to be installed as a dependency|`true`|
|`minio.install`|Allow MinIO Helm Chart to be installed as a dependency (chart default)|`true`|

These dependencies are integrated into the distribution by default. To deactivate them, specify each parameter using the --set key=value[,key=value] argument to helm install. For example:

```bash
helm install my-release \
  --set postgresql.install=false \
  --set database.endpoint=my-postgresql.host.local \
  --set database.port=5432 \
  --set database.user=my-user \
  --set database.password=my-password \
  reportportal/reportportal
```

> **Note:** If you disable install dependencies, you must provide new values (e.g., host, port, username, etc) for your predeployed dependencies.

All configuration variables are presented in the [values.yaml](https://github.com/reportportal/kubernetes/blob/master/reportportal/values.yaml) file.

### Ingress controller recommendation

ReportPortal recommends using the **nginx ingress controller** for exposing the application. Other ingress controllers (e.g. AWS ALB) are supported; nginx provides the most tested and reliable configuration. See [Install NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/).

### Storage configuration

ReportPortal supports storage types: **minio** (chart default), **s3**, and **filesystem**.

### Pod Disruption Budgets and Resource Quotas

For production you can enable pod disruption budgets and resource quotas:

```bash
helm install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  --set podDisruptionBudget.enabled=true \
  --set resourceQuota.enabled=true \
  --set resourceQuota.services=15 \
  --set resourceQuota.cpu=6 \
  --set resourceQuota.memory=8Gi \
  reportportal/reportportal
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resourceQuota.services` | Maximum number of services | `12` |
| `resourceQuota.cpu` | Total CPU limit | `6` |
| `resourceQuota.memory` | Total memory limit | `8Gi` |

Pod Disruption Budgets require multiple replicas for high availability.

### Install from sources

For fetching chart dependencies, use the command:

```bash
helm dependency build .
```

> This command fetches all the dependencies [required](https://github.com/reportportal/kubernetes/blob/master/reportportal/Chart.yaml) by the chart.

To install the chart directly from local sources, use:

```bash
helm install my-release --set uat.superadminInitPasswd.password="MyPassword" ./reportportal
```

### Install specific version

To search for available versions of a chart, use:

```bash
helm search repo reportportal --versions
```

To install a specific version of a chart, use:

```bash
helm install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  reportportal/reportportal \
  --version 23.2
```

## Documentation

* [General User Manual](https://reportportal.io/docs/)
* [Expert guide and hacks for deploying ReportPortal on Kubernetes](https://reportportal.io/docs/installation-steps/deploy-with-kubernetes/)
* [Quick Start Guide for Google Cloud Platform GKE](./docs/quick-start-gcp-gke.md)

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

- **PostgreSQL** - [PostgreSQL License](https://www.postgresql.org/about/licence/)
- **RabbitMQ** - [Mozilla Public License 2.0](https://www.rabbitmq.com/mpl.html)
- **OpenSearch** - [Apache License 2.0](https://github.com/opensearch-project/OpenSearch/blob/main/LICENSE.txt)
- **MinIO** - [GNU Affero General Public License v3.0](https://github.com/minio/minio/blob/master/LICENSE) (chart default object storage)
- **SeaweedFS** - [Apache License 2.0](https://github.com/seaweedfs/seaweedfs/blob/master/LICENSE) (recommended alternative since chart 26.3.12)
