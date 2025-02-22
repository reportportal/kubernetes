APP_NAME=reportportal
SUPERADMIN_PASSWORD=superadmin
STORAGE_TYPE=minio
MINIKUBE_CPUS=4
MINIKUBE_MEMORY=8192
MINIKUBE_DISK_SIZE=50g
REPO_URL=oci://us-docker.pkg.dev
CHART_NAME=$(shell yq e '.name' reportportal/Chart.yaml)
CHART_VERSION=$(shell yq e '.version' reportportal/Chart.yaml)
HELM_PACKAGE=${CHART_NAME}-${CHART_VERSION}.tgz

ifeq ($(STORAGE_TYPE), minio)
	MINIO_INSTALL=true
else
	MINIO_INSTALL=false
endif

default: package

install: install-source

# Helm commands
package:
	@ echo "Packaging ReportPortal as ${HELM_PACKAGE}"
	@ helm package ./reportportal

push:
	@ echo "Pushing ReportPortal as ${HELM_PACKAGE} to ${REPO_URL}"
	@helm push ${HELM_PACKAGE} ${REPO_URL}

install-source: deps-update deps-build repo-add repo-update
	@ echo "Installing ReportPortal as ${APP_NAME} from source."
	@ echo "Superadmin password: ${SUPERADMIN_PASSWORD}, storage type: ${STORAGE_TYPE}"
	@ helm install ${APP_NAME} \
		./reportportal \
		--set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
		--set storage.type=${STORAGE_TYPE} \
		--set minio.install=${MINIO_INSTALL}

install-repo: repo-add repo-update
	@ echo "Installing ReportPortal as ${APP_NAME} from repository."
	@ echo "Superadmin password: ${SUPERADMIN_PASSWORD}, storage type: ${STORAGE_TYPE}"
	@ helm install ${APP_NAME} \
		reportportal/reportportal \
		--set uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
		--set storage.type=${STORAGE_TYPE} \
		--set minio.install=${MINIO_INSTALL}

test:
	@ echo "Testing ReportPortal as ${APP_NAME}"
	@ helm test ${APP_NAME}

update:
	@ echo "Updating ReportPortal as ${APP_NAME}"
	@ helm upgrade ${APP_NAME} ./reportportal

uninstall:
	@ echo "Uninstalling reportportal"
	@ helm uninstall reportportal

deps-update:
	@ echo "Updating dependencies for ReportPortal"
	@ helm dependency update ./reportportal

deps-build:
	@ echo "Building dependencies for ReportPortal"
	@ helm dependency build ./reportportal

repo-add:
	@ echo "Adding Helm repository"
	@ helm repo add reportportal https://reportportal.io/kubernetes
	@ helm repo add bitnami https://charts.bitnami.com/bitnami
	@ helm repo add opensearch https://opensearch-project.github.io/helm-charts

repo-update:
	@ echo "Updating ReportPortal repository"
	@ helm repo update reportportal
	@ helm repo update bitnami
	@ helm repo update opensearch

# Chart versioning
chart-info:
	@ echo "Chart name: ${CHART_NAME}"
	@ echo "Chart version: ${CHART_VERSION}"

# Minikube commands
minikube-start:
	@ echo "Starting minikube with ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_MEMORY} memory"
	@ minikube start --cpus ${MINIKUBE_CPUS} --memory ${MINIKUBE_MEMORY} --addons ingress

minikube-stop:
	@ echo "Stopping minikube"
	@ minikube stop

minikube-delete:
	@ echo "Deleting minikube"
	@ minikube delete

minikube-address:
	@ echo "Minikube address http://$(shell minikube ip)"