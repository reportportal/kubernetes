# Install ReportPortal on Minikube

- [Install ReportPortal on Minikube](#install-reportportal-on-minikube)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Start Minikube](#start-minikube)
    - [Set up hostnames](#set-up-hostnames)
    - [Install ReportPortal](#install-reportportal)
      - [Install from Helm repo](#install-from-helm-repo)
      - [Install from GitHub repo](#install-from-github-repo)
    - [Access ReportPortal](#access-reportportal)
  - [Clean up](#clean-up)

## Prerequisites

- [Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)

## Installation

### Start Minikube

```bash
minikube start --cpus 4 --memory 8192 --addons ingress
```

### Set up hostnames

Add the following line to your `/etc/hosts` file:

```bash
echo "$(minikube ip) minikube.local" | sudo tee -a /etc/hosts
```

### Install ReportPortal

#### Install from Helm repo

```bash
helm repo add reportportal https://reportportal.io/kubernetes && helm repo update reportportal
```

```bash
export SUPERADMIN_PASSWORD=superadmin

helm install reportportal \
  reportportal/reportportal \
  --set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD}
```

#### Install from GitHub repo

Call the following commands from the downloaded [kubernetes](https://github.com/reportportal/kubernetes/) repository.

```bash
# Dowload the chart dependencies
helm dependency build ./reportportal 
```

```bash
# Install ReportPortal from ./reportportal/Chart.yaml
export SUPERADMIN_PASSWORD=superadmin

helm install reportportal \
  ./reportportal \
  --set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
  --set storage.type=filesystem \
  --set minio.install=false
```

### Access ReportPortal

Open your browser and navigate to [http://reportportal.local](http://minikube.local).

## Clean up

```bash
helm uninstall reportportal
```

```bash
minikube stop && minikube delete
```
