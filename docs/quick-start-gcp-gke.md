# Quick Start Guide for Google Cloud Platform GKE

- [Quick Start Guide for Google Cloud Platform GKE](#quick-start-guide-for-google-cloud-platform-gke)
  - [Prerequisites](#prerequisites)
  - [Initialize the gcloud CLI](#initialize-the-gcloud-cli)
  - [Set up gcloud credential helper](#set-up-gcloud-credential-helper)
  - [Adjust Google Cloud IAM](#adjust-google-cloud-iam)
  - [Create a GKE cluster](#create-a-gke-cluster)
    - [Create a cluster in Autopilot mode](#create-a-cluster-in-autopilot-mode)
    - [Create a cluster in Standard mode](#create-a-cluster-in-standard-mode)
    - [Get cluster credentials for kubectl](#get-cluster-credentials-for-kubectl)
    - [Verify the cluster mode](#verify-the-cluster-mode)
  - [Prepare Helm package for installation](#prepare-helm-package-for-installation)
    - [Create a repository](#create-a-repository)
    - [Build and push Helm chart](#build-and-push-helm-chart)
  - [Install ReportPortal on GKE Autopilot Cluster via Helm chart](#install-reportportal-on-gke-autopilot-cluster-via-helm-chart)
    - [Install ReportPortal from Artifact Registry](#install-reportportal-from-artifact-registry)
  - [Install Helm chart on GKE Standard Cluster](#install-helm-chart-on-gke-standard-cluster)
    - [Ingress configuration](#ingress-configuration)
  - [Clean up](#clean-up)

## Prerequisites

Before you begin, you need to have a Google Cloud account, a project and install the following
tools:

- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) 1.28 or later
- [Helm](https://helm.sh/docs/intro/install/) 3.11 or later
- [google-cloud-cli](https://cloud.google.com/sdk/docs/install-sdk) and
[gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin)

> **Note:** For some operation systems we recommend install `google-cloud-sdk` package instead of `google-cloud-cli`.

## Initialize the gcloud CLI

[Perform initial setup tasks](https://cloud.google.com/sdk/docs/initializing) and set up your default project:

```bash
gcloud init
```

## Set up gcloud credential helper

If you have Docker, you can use the Docker credential helper to authenticate to Artifact Registry.

> **Note:** Here and below we use `us-central1` region as a location for GKE cluster.
> However, you can use any other region.

Just perform the following commands:

```bash
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

You can find more information about gcloud credential helper
[here](https://cloud.google.com/artifact-registry/docs/docker/authentication#gcloud-helper).

## Adjust Google Cloud IAM

Installation of ReportPortal requires setting up access to your GKE cluster for creating
a service account in GKE and providing permissions for some services to access Kubernetes API.

For adjusting access, you can do it using both Identity and Access Management (IAM)
and Kubernetes RBAC.
Read about it [here](https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control#iam-interaction).

You can use [Predefined GKE Roles](https://cloud.google.com/kubernetes-engine/docs/how-to/iam#predefined) and update
your account role. To set a service account on nodes, you must also have the Service Account User role (roles/iam.serviceAccountUser).

> **Impotent** We recommend to create a separate [IAM Service Account](https://cloud.google.com/iam/docs/service-accounts-create)
> for working with GKE cluster.

## Create a GKE cluster

> **Important:** All GKE clusters are created as public clusters by default.

You can create [two types](https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#modes)
of GKE clusters:

- [Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Standard](https://cloud.google.com/kubernetes-engine/docs/concepts/choose-cluster-mode#why-standard)

> **Note:** We recommend to use Autopilot mode.
> It is a managed Kubernetes environment that reduces the operational cost.

### Create a cluster in Autopilot mode

It's pretty simple to create a cluster in Autopilot mode:

```bash
gcloud container clusters create-auto reportportal-cluster \
    --location=us-central1
```

For more information about creating a cluster in Autopilot mode you can find
[here](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-an-autopilot-cluster).

> **Note:** Here and below we use `us-central1` region as a location for GKE cluster.
> However, you can use any other region.

### Create a cluster in Standard mode

For a standard cluster you need to specify a machine type and a number of nodes.

ReportPortal requires at least 3 nodes with 2 vCPU and 4 GB memory for each.
We recommend using `e2-standard-2` machine type with 2 vCPU and 8 GB memory:

```bash
gcloud container clusters create reportportal-cluster \
    --zone=us-central1-a \
    --machine-type=e2-standard-2 --num-nodes=3
```

More information about creating a cluster in Standard mode you can find
[here](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster#gcloud).

### Get cluster credentials for kubectl

```bash
gcloud container clusters get-credentials reportportal-cluster \
    --location=us-central1
```

### Verify the cluster mode

You can verify the cluster:

```bash
gcloud container clusters describe reportportal-cluster \
    --location=us-central1
```

## Prepare Helm package for installation

At the current moment, you can install ReportPortal on GKE cluster via Helm chart only from
develop branch.

### Create a repository

Create a repository in Artifact Registry for ReportPortal Helm charts:

```bash
gcloud artifacts repositories create reportportal-helm-repo --repository-format=docker \
--location=us-central1 --description="ReportPortal Helm repository"
```

> More information about Store Helm charts in the Artifact Registry you can find
> [here](https://cloud.google.com/artifact-registry/docs/helm/store-helm-charts).

Verify that the repository was created:

```bash
gcloud artifacts repositories list
```

Authenticate with the repository:

```bash
gcloud auth print-access-token | helm registry login -u oauth2accesstoken \
--password-stdin https://us-central1-docker.pkg.dev
```

### Build and push Helm chart

Add GitHub repository on your local machine:

```bash
git clone https://github.com/reportportal/kubernetes.git
```

Build and push the Helm chart to Artifact Registry using actual helm chart version
and your project id:

```bash
cd kubernetes
helm package .
helm push reportportal-${VERSION}.tgz oci://us-central1-docker.pkg.dev/${PROJECT_ID}/reportportal-helm-repo
```

## Install ReportPortal on GKE Autopilot Cluster via Helm chart

By default, ReportPortal Helm chart install with infrastructure dependencies in GKE Autopilot Cluster:

- PostgreSQL
- OpenSearch
- RabbitMQ
- MinIO

You can disable an installation of some components via Helm chart values, but you have to provide
new credentials for your standalone components.

More information about it you can find here:
[Install the chart with dependencies](https://github.com/reportportal/kubernetes#install-the-chart-with-dependencies).

### Install ReportPortal from Artifact Registry

For installing ReportPortal on GKE Autopilot Cluster, you need to set the:

- ingress controller as a `gke`
- superadmin password
- resources requests for api, uat, and analyzer services

```bash
helm install \
    --set ingress.class="gke" \
    --set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
    --set uat.resources.requests.memory="1Gi" \
    --set serviceapi.resources.requests.cpu="1000m" \
    --set serviceapi.resources.requests.memory="2Gi" \
    --set serviceanalyzer.resources.requests.memory="1Gi" \
    reportportal \
    oci://us-central1-docker.pkg.dev/${PROJECT_ID}/reportportal-helm-repo/reportportal \
    --version ${VERSION}
```

## Install Helm chart on GKE Standard Cluster

For installing ReportPortal on GKE Standard Cluster you need to set:

- ingress controller as a `gke`
- superadmin password

```bash
helm install \
    --set ingress.class="gke" \
    --set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
    reportportal \
    oci://us-central1-docker.pkg.dev/${PROJECT_ID}/reportportal-helm-repo/reportportal \
    --version ${VERSION}
```

### Ingress configuration

You can add custom gke ingress annotations via `ingress.annotations.gke` parameter:

```bash
--set-json='ingress.annotations.gke={"key1":"value1","key2":"value2"}'
```

If you have some domain name, set `ingress.usedomainname` variable to `true` and
set this FQDN to `ingress.hosts`:

```bash
--set ingress.usedomainname=true \
--set ingress.hosts[0].reportportal.k8.com
```

## Clean up

To delete the cluster:

```bash
gcloud artifacts repositories delete reportportal-cluster --location=us-central1
```

To delete the artifacts repository:

```bash
gcloud artifacts repositories delete reportportal-helm-repo --location=us-central1
```
