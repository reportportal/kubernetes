# [ReportPortal.io](http://ReportPortal.io) Helm chart repository

## Description

These charts bootstraps a ReportPortal deployment on a Kubernetes cluster using the Helm package manager. The repo includes a number of Kubernetes and Helm configurations for installation ReportPortal v5. 

To deploy ReportPortal to Kubernetes use following [Installation guide](https://github.com/reportportal/kubernetes/blob/develop/reportportal/README.md)

> [Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

## Installing

### Install released version using Helm repository

Add the ReportPortal Helm charts repo: `helm repo add reportportal https://reportportal.github.io/kubernetes`

* Install it:
    * with Helm 3: `helm install my-reportportal reportportal/reportportal`
    * with Helm 2 (deprecated): `helm install --name my-reportportal reportportal/reportportal`

### Install custom version using Helm repository

* Install it:
    * with Helm 3: `helm install my-reportportal reportportal/reportportal --version=5.6.3`
    * with Helm 2 (deprecated): `helm install --name my-reportportal reportportal/reportportal --version=5.6.3`

### Install reportportal with custom values file using Helm repository

* Install it:
    * with Helm 3: `helm install my-reportportal --values=values.yaml reportportal/reportportal`
    * with Helm 2 (deprecated): `helm install --name my-reportportal --values=values.yaml reportportal/reportportal`

## Uninstalling

To remove Hlem Chart use the following command: `helm uninstall my-reportportal reportportal/reportportal`

