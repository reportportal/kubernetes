# K8s
Kubernetes/Helm configs for installation ReportPortal

**Overall information**

This Helm project is created to setup ReportPortal with only one commando. It installs all mandatory services to run the application.

The Chart installation consist of the following .yaml files:

- Statefulset and Service files of: `Analyzer, Api, Index, Migrations, UAT, UI, RabbitMq, PostgreSQL, Elasticsearch` that are used for deployment and communication between services
- `Ingress` objects to access the UI
- `values.yaml` which exposes a few of the configuration options in the charts
- `templates/_helpers.tpl` file which contains helper templates.

ReportPortal use the following images:

- serviceindex: reportportal/service-index
- uat: reportportal/service-authorization
- serviceui: reportportal/service-ui
- serviceapi: reportportal/service-api
- migrations: reportportal/migration
- serviceanalyzer: reportportal/service-analyzer

Requirements: 

- `RabbitMQ`
- `ElasticSearch`
- `PostgreSQL` 

Before you deploy ReportPortal you should have installed all requirements.
All variables are presented in the value.yaml file.

To deploy ReportPortal you should have Kubernetes cluster up and running. Please follow the guides below to run your Kubernetes cluster on different platforms


### Minikube installation

Minikube is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes cluster inside a Virtual Machine (VM) on your laptopS

##### Prerequisites

Make sure you have kubectl installed. You can install kubectl according to the instructions in [Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux) guide

##### Install Minikube

> Linux

There are experimental packages for Minikube available; you can find Linux (AMD64) packages from Minikube’s releases page on GitHub

If you’re not installing via a package, you can download a stand-alone binary and use that:

```sh
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube
```

Here’s an easy way to add the Minikube executable to your path:

```sh
sudo install minikube /usr/local/bin
```

> MacOS

The easiest way to install Minikube on macOS is using Homebrew:

```sh
brew cask install minikube
```

You can also install it on macOS by downloading a stand-alone binary:

```sh
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64 \
  && chmod +x minikube
```

Here’s an easy way to add the Minikube executable to your path:

```sh
sudo mv minikube /usr/local/bin
```

> Windows

The easiest way to install Minikube on Windows is using [Chocolatey](https://chocolatey.org) (run as an administrator):

```sh
choco install minikube kubernetes-cli
```

After Minikube has finished installing, close the current CLI session and restart. Minikube should have been added to your path automatically

To install Minikube manually on Windows using Windows Installer, download [minikube-installer.exe](https://github.com/kubernetes/minikube/releases/latest/minikube-installer.exe) and execute the installer

##### Run the application in Minikube

Start to minikube with the options:
```sh
minikube --memory 4096 --cpus 2 start
```

Install Ingress plugin:
```sh
minikube addons enable ingress
```

Verify that the NGINX Ingress controller is running
```sh
kubectl get pods -n kube-system
```

Initialize Helm package manager:
```sh
helm init
```

> Before you deploy ReportPortal you should have installed requirements. Versions are described in requirements.yaml.
> Also you should specify correct PostgreSQL, ElasticSearch and RabbitMQ addresses and ports in values.yaml. Also it could be an external existing installation:
```
postgresql:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    external: true
    address: db-postgresql.default.svc.cluster.local
    port: 5432
    user: rpuser
    dbName: reportportal

rabbitmq:
  SecretName: ""
  installdep:
    enable: false
  endpoint: 
    external: true
    address: mq-rabbitmq-ha.default.svc.cluster.local
    port: 5672
    user: rabbitmq
    apiport: 15672
    apiuser: rabbitmq

elasticsearch:
  installdep:
    enable: false
  endpoint:
    external: true
    address: <es_chart_name>-elasticsearch-client.default.svc
    port: 9200
```

Deploy the chart:
```sh
helm install ./<project folder>`
```

Once it's installed please make sure that the PersistentVolumes directories are created

Commando to create those folders:
- `minikube ssh`
- `sudo mkdir /mnt/data/db -p`
- `sudo mkdir /mnt/data/console -p`
- `sudo mkdir /mnt/data/elastic -p`

Also make sure that the vm.max_map_count is setup:
```sh
minikube ssh
```
```sh
sudo sysctl -w vm.max_map_count=262144
```

The default URL to reach ReportPortal page is http://reportportal.k8.com
Make sure that the URL is added to the host file and the IP is the K8s IP address

The command to get an IP address of Minikube:
```sh
minikube ip
```
Example for host file:
```sh
192.168.99.100 reportportal.k8.com
```

### Cloud Computing Services platform installation

1. Make sure you have Kubernetes up and running

> Kubernetes on AWS

There are two options to use Kubernetes on AWS:
- `Manage Kubernetes infrastructure yourself with Amazon EC2`
- `Get an automatically provisioned, managed Kubernetes control plane with Amazon EKS`

We recommend you to go with the second option, and use Amazon EKS.

To create and configure your AWS EKS Cluster you can use either the AWS console or AWS CLI -> [Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

> Kubernetes on  GCP

Please use Google Kubernetes Engine for hosted Kubernetes cluster installation and management on GCP.

To run your K8s cluster on GKE use the following [Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-cluster)

You can find more detailed information about GKE [here](https://cloud.google.com/kubernetes-engine/docs/)

> Kubernetes on Azure

The Azure Kubernetes Service (AKS) offers simple deployments for Kubernetes clusters.

To deploy an AKS cluster use the following guides:
- [By using the Azure portal](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough-portal)
- [By using the Azure CLI](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough)

> Kubernetes on DigitalOcean

To create a Kubernetes cluster on DigitalOcean cloud use the following guide:

[How to Create Kubernetes Clusters Using the Control Panel](https://www.digitalocean.com/docs/kubernetes/how-to/create-clusters/)

2. Install and configure Helm package manager 

For more information about installation the Helm package manager on different Kubernetes clusters, use the following:

- [AWS](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)
- [GCP](https://helm.sh/docs/using_helm/#installing-helm)
- [Azure](https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm)
- [DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-install-software-on-kubernetes-clusters-with-the-helm-package-manager)

You can test your Helm configuration by installing a simple Helm chart like a Wordpress
```
$ helm install stable/wordpress
```
Do not forget to clean up the Wordpress chart resources after making sure everything works as expected

3. Deploy NGINX Ingress controller

Please find the guides below:

- [AWS](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#aws)
- [GCP ](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#gce-gke)
- [Azure](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#azure)
- [DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-on-digitalocean-kubernetes-using-helm#step-2-%E2%80%94-installing-the-kubernetes-nginx-ingress-controller)

4. Reportportal requires installed [postgresql](https://github.com/helm/charts/tree/master/stable/postgresql), [elasticsearch](https://github.com/elastic/helm-charts/tree/master/elasticsearch) and [rabbitmq](https://github.com/helm/charts/tree/master/stable/rabbitmq-ha) to run. Required versions of helm charts are described in requirements.yaml
If you don't have your own postgresql and rabbitmq instances, they can be installed from official helm charts. 

For example to install postgresql please use this commands:
```sh
helm dependency build ./reportportal/
helm install --name <postgresql_chart_name> --set postgresqlUsername=rpuser,postgresqlPassword=<rpuser_password>,postgresqlDatabase=reportportal ./reportportal/charts/postgresql-3.9.1.tgz
```
Once PostgreSQL has been deployed, copy address and port from output notes. Should be something like this:
```
** Please be patient while the chart is being deployed **

PostgreSQL can be accessed via port 5432 on the following DNS name from within your cluster:

    <postgresql_chart_name>-postgresql.default.svc.cluster.local - Read/Write connection
To get the password for "postgres" run:

    export POSTGRESQL_PASSWORD=$(kubectl get secret --namespace default <postgresql_chart_name>-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)

To connect to your database run the following command:

    kubectl run <postgresql_chart_name>-postgresql-client --rm --tty -i --restart='Never' --namespace default --image bitnami/postgresql --env="PGPASSWORD=$POSTGRESQL_PASSWORD" --command -- psql --host <postgresql_chart_name>-postgresql -U postgres

To connect to your database from outside the cluster execute the following commands:

    kubectl port-forward --namespace default svc/<postgresql_chart_name>-postgresql 5432:5432 &
    psql --host 127.0.0.1 -U postgres
```

Elasticsearch chart can be installed in the same manner:
```sh
helm install --name <es_chart_name> ./reportportal/charts/elasticsearch-1.17.0.tgz
```
RabbitMQ chart can be installed in the same manner:
```sh
helm install --name <rabbitmq_chart_name> --set rabbitmqUsername=rabbitmq,rabbitmqPassword=<rmq_password> ./reportportal/charts/rabbitmq-ha-1.18.0.tgz
```

Once RabbitMQ has been deployed, copy address and port from output notes. Should be something like this:

```
** Please be patient while the chart is being deployed **

  Credentials:

    Username      : rabbitmq
    Password      : $(kubectl get secret --namespace default <rabbitmq_chart_name>-rabbitmq-ha -o jsonpath="{.data.rabbitmq-password}" | base64 --decode)
    ErLang Cookie : $(kubectl get secret --namespace default <rabbitmq_chart_name>-rabbitmq-ha -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 --decode)


  RabbitMQ can be accessed within the cluster on port 5672 at <rabbitmq_chart_name>-rabbitmq-ha.default.svc.cluster.local

  To access the cluster externally execute the following commands:

    export POD_NAME=$(kubectl get pods --namespace default -l "app=rabbitmq-ha" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $POD_NAME --namespace default 5672:5672 15672:15672

  To Access the RabbitMQ AMQP port:

    amqp://127.0.0.1:5672/

  To Access the RabbitMQ Management interface:

    URL : http://127.0.0.1:15672
```

5. After PostgreSQL and RabbitMQ are up and running, edit values.yaml to adjust ReportPortal settings

Insert the real values of PostgreSQL and RabbitMQ addresses and ports:
```
postgresql:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    external: true
    address: db-postgresql.default.svc.cluster.local
    port: 5432
    user: rpuser
    dbName: reportportal

rabbitmq:
  SecretName: ""
  installdep:
    enable: false
  endpoint: 
    external: true
    address: mq-rabbitmq-ha.default.svc.cluster.local
    port: 5672
    user: rabbitmq
    apiport: 15672
    apiuser: rabbitmq
    
elasticsearch:
  installdep:
    enable: false
  endpoint:
    external: true
    address: <es_chart_name>-elasticsearch-client.default.svc
    port: 9200
```
Adjust resources for each pod if needed:
```
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 512Mi
```
If you are going to associate a specific DNS name for your UI, set Ingress controller configuration like this:
```
# ingress configuration for the ui
ingress:
..
  usedomainname: true
  hosts:
    - reportportal.k8.com
```

6. Creation of ReportPortal data in PostgreSQL db required the ltree extension installation. This, in turn, required Super user access to 'rpuser' (PostgreSQL user for ReportPortal database)

Therefore, please change 'rpuser' to a superuser in PostgreSQL installed by Helm chart by doing the following:

Get a shell to a running Postgresql container:
```
kubectl exec -it postgresqlchart-postgresql-0 -- /bin/bash
```
Connect to the database as 'postgres' user and upgrade 'rpuser' to be a superuser:
```
psql -h 127.0.0.1 -U postgres
ALTER USER rpuser WITH SUPERUSER;
```
Exit
```
\q
exit
```

7. Once everything is ready, the ReportPortal Helm Chart package can be created and deployed by executing:
```sh
helm package ./reportportal/
helm install --name <reportportal_chart_name> --set postgresql.SecretName=<db_chart_name>-postgresql,rabbitmq.SecretName=<rabbitmq_chart_name>-rabbitmq-ha ./reportportal-5.0-SNAPSHOT.tgz
```

8. Once ReportPortal is deployed, you can validate application is up and running by opening your NodePort / LoadBalancer address:

```sh
kubectl get service
```

As an example
```example
gateway   NodePort   10.233.48.187  <none>     80:31826/TCP,8080:31135/TCP  2s
```

If you expose your application with an Ingress controller, note LoadBalancer's EXTERNAL-IP address instead

9. Open http://10.233.48.187:8080 page in your browser. Defalut login and password is:
```
default
1q2w3e
```
P.S: If you can't login - please check logs of api and uat pods. It take some time to initialize

### Run ReportPortal over SSL (HTTPS)

1. Configure a custom domain name for your ReportPortal website

Set up a domain name you own at the domain registrar

2. Pre-requisite configuration

In order to enable HTTPS, you need to get a SSL/TLS certificate from a Certificate Authority (CA).
As a free option, you can use Let's Encrypt - a non-profit TLS CA. Its purpose is to try to make a safer internet by making it easier and cheaper to use TLS.

2.1. Deploy Cert Manager (e.g. in kube-system namespace)

[Cert-manager](https://github.com/helm/charts/tree/master/stable/cert-manager) is a native Kubernetes certificate management controller. It can help with issuing certificates from a variety of sources, such as Let’s Encrypt, HashiCorp Vault, Venafi, a simple signing keypair, or self-signed.

```sh
## Install the cert-manager CRDs **before** installing the cert-manager Helm chart
kubectl apply \
    -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml
```

```sh
## Ensure the namespace has an additional label on it in order for the deployment to succeed
kubectl label namespace kube-system certmanager.k8s.io/disable-validation="true"
```

```sh
## Install the cert-manager helm chart
helm install --name cert-manager stable/cert-manager
```

2.2. Create a Let's Encrypt CA ClusterIssuer Kubernetes resource
 
Issuers (and ClusterIssuers) represent a certificate authority from which signed x509 certificates can be obtained, such as Let’s Encrypt. You will need at least one Issuer or ClusterIssuer in order to begin issuing certificates within your cluster

```sh
vi letsencrypt-clusterissuer.yaml
```

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
 # The ACME server URL
 server: https://acme-staging-v02.api.letsencrypt.org/directory
 # Email address used for ACME registration
 email: user@example.com
 # Name of a secret used to store the ACME account private key
 privateKeySecretRef:
name: letsencrypt-prod
 # Enable the HTTP-01 challenge provider
 http01: {}
```

```sh
kubectl create -f letsencrypt-clusterissuer.yaml
```

3. Reconfigure/redeploy your ReportPortal installation with a new Ingress Configuration to be access at a TLS endpoint

With all the pre-requisite configuration in place, we can now do the pieces to request the TLS certificate.

3.1. Edit values.yaml and api-ingress.yaml, and add certmanager annotations:

```
..
annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    certmanager.k8s.io/issuer: "letsencrypt-prod"
    certmanager.k8s.io/acme-challenge-type: http01
```

3.2. Add TLS to the both ReportPortal Ingress Configuration files

Edit 'gateway-ingress.yaml' and 'api-ingress.yaml' in order to add your TLS information.
 
Let's suppose your domain name is 'my.reportportal.com ' and your certificate name is 'my.reportportal.com-tls'. Then you should add the following under the 'spec':

```
tls:
  - hosts:
    - my.reportportal.com
    secretName: my.reportportal.com-tls
```

The result in should look like:

```
spec:
  tls:
  - hosts:
    - my.reportportal.com
    secretName: my.reportportal.com-tls
  rules:
{{ if .Values.ingress.usedomainname }}
  {{- range $host := .Values.ingress.hosts }}
  - host: {{ $host }}
...
```

3.3. Redeploy your application

4.  Create a Certificate resource in Kubernetes with acme http challenge configured:

```sh
vi kubectl create -f certificate-tls.yaml
```

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: my.reportportal.com-tls
spec:
  secretName: my.reportportal.com-tls
  dnsNames:
  - my.reportportal.com
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - my.reportportal.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

Once this resource is created, there should be a tls cert that is created. If not, then check the logs of the cert-manger service for errors




