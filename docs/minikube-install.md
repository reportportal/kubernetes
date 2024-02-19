# Install ReportPortal on Minikube

- [Install ReportPortal on Minikube](#install-reportportal-on-minikube)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Start Minikube](#start-minikube)
    - [Set up hostnames](#set-up-hostnames)
    - [Install ReportPortal](#install-reportportal)
    - [Access ReportPortal](#access-reportportal)
  - [Clean up](#clean-up)

## Prerequisites

- [Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)

## Installation

### Start Minikube

```bash
minikube start --cpus 4 --memory 4096 --addons ingress
```

### Set up hostnames

Add the following line to your `/etc/hosts` file:

```bash
echo "$(minikube ip) reportportal.local" | sudo tee -a /etc/hosts
```

### Install ReportPortal

```bash
helm repo add reportportal https://reportportal.io/kubernetes && helm repo update reportportal
```

```bash
export SUPERADMIN_PASSWORD=superadmin

helm install reportportal reportportal/reportportal \
  --set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
   ${RELEASE_NAME}
```

### Access ReportPortal

Open your browser and navigate to [http://reportportal.local](http://reportportal.local).

## Clean up

```bash
helm uninstall reportportal
```

```bash
minikube stop && minikube delete
```
