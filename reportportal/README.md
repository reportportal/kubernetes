# ReportPortal on Kubernetes

Kubernetes/Helm configs for installation of ReportPortal

-----------
### Table of Contents

[Overall information](#overall-information)

[Minikube installation](#minikube-installation)
* [Prerequisites](#prerequisites)
* [Run ReportPortal in Minikube](#run-reportportal-in-minikube)

[Cloud Computing Services platform installation](#cloud-computing-services-platform-installation)
* [Make sure you have Kubernetes up and running](#1-make-sure-you-have-kubernetes-up-and-running)
* [Install and configure Helm package manager](#2-install-and-configure-helm-package-manager)
* [Deploy NGINX Ingress controller](#3-deploy-nginx-ingress-controller-version-0220)
* [Elasticsearch installation](#4-elasticsearch-installation)
* [RabbitMQ installation](#5-rabbitmq-installation)
* [PostgreSQL installation](#6-postgresql-installation)
* [MinIO installation](#7-minio-installation)
* [(OPTIONAL) Additional adjustments](#8-optional-additional-adjustments)
* [Deploy the ReportPortal Helm Chart](#9-deploy-the-reportportal-helm-chart)
* [Validate the pods and service](#10-validate-the-pods-and-service)
* [Start work with ReportPortal](#11-start-work-with-reportportal)

[Updating ReportPortal to the latest version](#updating-reportportal-to-the-latest-version)

[Run ReportPortal over SSL (HTTPS)](#run-reportportal-over-ssl-https)
* [Configure a custom domain name](#1-configure-a-custom-domain-name-for-your-reportportal-website)
* [Pre-requisite configuration](#2-pre-requisite-configuration)
* [Update your ReportPortal installation with a new Ingress Configuration](#3-update-your-reportportal-installation-with-a-new-ingress-configuration-to-be-access-at-a-tls-endpoint)
* [Create a Certificate resource in Kubernetes with acme http challenge configured](#4-create-a-certificate-resource-in-kubernetes-with-acme-http-challenge-configured)

-----------

### Overall information

This project is created to install ReportPortal on Kubernetes with Helm.

It describes installation of all mandatory services to run the application, and supports use of external cloud services to resolve the dependencies, such as Amazon RDS Service / Azure Database for PostgreSQL as a database, Amazon ES as an elasticsearch cluster and AmazonMQ brocker for RabbitMQ

#### The chart includes the following configuration files:

- Statefulset, Deployments and Service files of: `Analyzer`, `Api`, `Index`, `Migrations`, `UAT`, `UI` that are used for deployment and communication between services
- `Ingress` object to access the UI
- `values.yaml` which exposes a few of the configuration options
- `templates/_helpers.tpl` file which contains helper templates

#### ReportPortal use the following images:

- [`service-authorization`](https://github.com/reportportal/service-authorization) Authorization Service. In charge of access tokens distribution
- [`service-api`](https://github.com/reportportal/service-api) API Service. Application Backend
- [`service-ui`](https://github.com/reportportal/service-ui) UI Service. Application Frontend
- [`service-index`](https://github.com/reportportal/service-index) Index Service. Info and health checks per service.
- [`service-analyzer`](https://github.com/reportportal/service-auto-analyzer) Analyzer Service. Finds most relevant test fail prob

#### Requirements: 
- `RabbitMQ` (Helm chart installation)  
- `ElasticSearch` (Helm chart installation | Amazon Elasticsearch Service)  
- `PostgreSQL` (Helm chart installation | Amazon PostgreSQL RDS | Azure Database for PostgreSQL)  
- `MinIO` (Helm chart installation)  

All configuration variables are presented in `value.yaml` file.  

Before you deploy ReportPortal you should have installed all its dependencies (requirements). Run Amazon RDS PostgreSQL or Azure Database for PostgreSQL, Amazon ES cluster in case you go with an external cloud services option.  

You should have Kubernetes cluster is up and running. Please follow the guides below to run your Kubernetes cluster on different platforms.  

> For matching the installation commands on this guide with your command line, please download this Helm chart to your machine.

### Minikube

Minikube is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes cluster inside a Virtual Machine (VM) on your laptopS

#### Prerequisites

Make sure you have kubectl installed. You can install kubectl according to the instructions in [Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux) guide

#### Run ReportPortal in Minikube

Start Minikube with the options:  
```sh
minikube --memory 4096 --cpus 2 start
```

Install the Ingress plugin:  
```sh
minikube addons enable ingress
```

Verify that the NGINX Ingress controller is running:  
```sh
kubectl get pods -n kube-system
```

Initialize Helm package manager:  
```sh
helm repo add stable https://charts.helm.sh/stable && helm repo update
```


> Before you deploy ReportPortal you should have installed all its requirements. Their versions are described in requirements.yaml  
> You should also specify correct PostgreSQL and RabbitMQ addresses and ports in values.yaml  

```yaml
rabbitmq:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    address: <rabbitmq_chart_name>.default.svc.cluster.local
    port: 5672
    user: rabbitmq
    apiport: 15672
    apiuser: rabbitmq

postgresql:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    cloudservice: false
    address: <postgresql_chart_name>.default.svc.cluster.local
    port: 5432
    user: rpuser
    dbName: reportportal
    password: 
```

Deploy the chart:  
```sh
helm install ./<project folder>
```

Once it's installed please make sure that the PersistentVolumes directories are created  

To create:  
```sh
minikube ssh
```
```sh
sudo mkdir /mnt/data/db -p
```
```sh
sudo mkdir /mnt/data/console -p
```
```sh
sudo mkdir /mnt/data/elastic -p
```

Also make sure that the vm.max_map_count is setup:  
```sh
minikube ssh
```
```sh
sudo sysctl -w vm.max_map_count=262144
```

The default URL to reach the ReportPortal UI page is http://reportportal.k8.com.  
Make sure that the URL is added to your host file and the IP is the K8s IP address  

The command to get an IP address of Minikube:  
```sh
minikube ip
```
Example of the host file:
```sh
192.168.99.100 reportportal.k8.com
```

### Cloud Computing Services platform installation

#### 1. Make sure you have Kubernetes up and running

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

#### 2. Install and configure Helm package manager 

For more information about installation the Helm package manager on different Kubernetes clusters, use the following:

- [AWS](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)
- [GCP](https://helm.sh/docs/using_helm/#installing-helm)
- [Azure](https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm)
- [DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-install-software-on-kubernetes-clusters-with-the-helm-package-manager)

Confirm that Helm is running with the following command  
```
helm version
```

#### 3. Deploy NGINX Ingress controller (version 0.34.1)

Please find the guides below:

- [AWS](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#aws)
- [GCP ](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#gce-gke)
- [Azure](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#azure)
- [DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-on-digitalocean-kubernetes-using-helm#step-2-%E2%80%94-installing-the-kubernetes-nginx-ingress-controller)

Or you can istall an NGINX ingress controller using Helm. 

```
helm install reportportal nginx-ingress stable/nginx-ingress
```

> If you go with AWS, then after your NGINX Ingress controller automatically creates a Load Balancer and assigns a cname (for example `a1b6b2345kj1113744944ea67hdfh21llbe7f-639623130.eu-central-1.elb.amazonaws.com`), please increase its idle timeout to 300 seconds

#### 4. Elasticsearch installation

ReportPortal requires installation of Elasticsearch, RabbitMQ, PostgreSQL and MinIO. On this step we will start with Elasticsearch.  

You can go with [Elasticsearch Helm chart](https://github.com/elastic/helm-charts/tree/master/elasticsearch) (4.1) or use an Amazon ES as an Elasticsearch cluster (4.2).  

4.1. Elasticsearch Helm chart installation  

To use this type of installation, please run the following commands  

Add the elastic helm charts repo:
```sh
helm repo add elastic https://helm.elastic.co && helm repo update
```

The following command will use your ReportPortal dependency file requirements.yaml to download all the specified charts into your charts/ directory for you:
```sh
helm dependency build ./reportportal/
```

Install Elasticsearch:  
```sh
helm install <es_chart_name> ./reportportal/charts/elasticsearch-7.6.1.tgz
```

> Default Elasticsearch Helm chart configuration supposes you have at least 3 kubernetes nodes. If you have only one or two nodes, you will face with 'didn't match pod affinity/anti-affinity' issue. To solve this problem, rewrite the number of replicas by using 'replicas' value (3 by default), and run the installation command with an additional values file.  

4.2. Elasticsearch as an external cloud service. Connection to your AWS ElasticSearch cluster

Amazon Elasticsearch Service (Amazon ES) makes it easy to set up, operate, and scale an Elasticsearch cluster in the cloud  

(For more information about Amazon Elasticsearch Service please click on the following [link](https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html)  

4.2.1. Creation an Amazon Elasticsearch Service domain  

Please use the [Getting Started guide](https://docs.aws.amazon.com/en_us/elasticsearch-service/latest/developerguide/es-gsg-create-domain.html)

Feel free to choose whatever configuration fits you best  

4.2.2. Configuration the IAM Policy for your AWS Kubernetes Worker Nodes  

Amazon ES adds support for an authorization layer by integrating with IAM. You write an IAM policy to control access to the cluster’s endpoint, allowing or denying Actions (HTTP methods) against Resources  

IAM policies can be attached to your domain or to individual users or roles. If a policy is attached to your domain, it’s called a resource-based policy. If it’s attached to a user or role, it’s called a user-based policy  

We recommend to use an Resource-based access policy:  

  * Click on "Modify the access policy for <Your_AWS_ES_domain_name>";
  * Choose Allow access to the domain from specific IP(s) and enter
  * Enter the public IP addresses of your Worker Nodes; (Add a comma-separated list of valid IPv4 addresses or CIDR blocks)

4.2.3. Accessing your AWS ES domain from ReportPortal  

Get your AWS ES domain endpoint URL from the the "Overview" tab in AWS, and write down its value into the ReportPortal values.yaml:  

```yaml
elasticsearch:
  installdep:
    enable: false
  endpoint: <AWS ES domain Endpoint URL>
```

#### 5. RabbitMQ installation

You can install RabbitMQ from the following [RabbitMQ Helm chart](https://github.com/bitnami/charts/tree/master/bitnami/rabbitmq) (5.1) or use an AmazonMQ as RabbitMQ (5.2).  

5.1 RabbitMQ from the Helm chart

Download the specified chart into your charts/ directory:  
```sh
helm dependency build ./reportportal/
```

Then use to install it:  
```sh
helm install <rabbitmq_chart_name> --set auth.username=rabbitmq,auth.password=<rmq_password>,replicaCount=1 ./reportportal/charts/rabbitmq-7.5.6.tgz
```

> Please be aware of api deprecations in Kubernetes 1.16.  
It can cause the following issue on some Helm charts: Error: validation failed: unable to recognize "": no matches for kind "StatefulSet" in version "apps/v1beta1.
The issue is coming from the 3rd party dependencies which listed deprecated API versions.
As a workaround, please use [compatible versions of Kubernetes](https://github.com/reportportal/kubernetes#requirements). 

Once RabbitMQ has been deployed, copy address and port from output notes. Should be something like this:
```
** Please be patient while the chart is being deployed **

Credentials:

    echo "Username      : rabbitmq"
    echo "Password      : $(kubectl get secret --namespace default rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 --decode)"
    echo "ErLang Cookie : $(kubectl get secret --namespace default rabbitmq -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 --decode)"

RabbitMQ can be accessed within the cluster on port  at rabbitmq.default.svc.

To access for outside the cluster, perform the following steps:

To Access the RabbitMQ AMQP port:

    echo "URL : amqp://127.0.0.1:5672/"
    kubectl port-forward --namespace default svc/rabbitmq 5672:5672

To Access the RabbitMQ Management interface:

    echo "URL : http://127.0.0.1:15672/"
    kubectl port-forward --namespace default svc/rabbitmq 15672:15672
```

When RabbitMQ is up and running, edit values.yaml to adjust the settings  

Insert the real values of RabbitMQ address and ports:  

```yaml
rabbitmq:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    address: <rabbitmq_chart_name>.default.svc.cluster.local
    port: 5672
    user: rabbitmq
    apiport: 15672
    apiuser: rabbitmq
```

After the pod gets the status Running, you need to configure the RabbitMQ memory threshold

```bash
kubectl exec -it <rabbitmq_pod_name> -- rabbitmqctl set_vm_memory_high_watermark 0.8
```

5.2 RabbitMQ as AmazoneMQ brocker

Amazon MQ is a managed message broker service for that makes it easy to migrate to a message broker in the cloud. Use the AWS manual to create [RabbitMQ brocker](https://docs.aws.amazon.com/amazon-mq/latest/developer-guide/getting-started-rabbitmq.html#create-rabbitmq-broker)

Edit `api-deployment.yaml` in `reportportal/templates/` folder

```yaml
{{ if .Values.rabbitmq.endpoint.cloudservice }}
- name: RP_AMQP_ADDRESSES
  value: "amqps://{{ .Values.rabbitmq.endpoint.user }}:{{ .Values.rabbitmq.endpoint.password }}@{{ .Values.rabbitmq.endpoint.address }}:{{ .Values.rabbitmq.endpoint.port }}"
- name: RP_AMQP_API_ADDRESS
  value: "https://{{ .Values.rabbitmq.endpoint.user }}:{{ .Values.rabbitmq.endpoint.password }}@{{ .Values.rabbitmq.endpoint.address }}/api"
{{ end }}
```

Edit values.yaml in `reportportal/` folder

```yaml
rabbitmq:
  SecretName: ''
  installdep:
    enable: false
  endpoint:
    cloudservice: true
    address: <RABBITMQ_CLOUD_ADDRESS>
    port: <RABBITMQ_PORT>  # for example 5671
    user: <RABBITMQ_USERNAME>
    apiport: 1<RABBITMQ_PORT>  # for expample 15671
    apiuser: <RABBITMQ_USERNAME>
    password: <RABBITMQ_PASSWORD>
```

#### 6. PostgreSQL installation

You can install PostgreSQL from the [PostgreSQL Helm chart](https://github.com/helm/charts/tree/master/stable/postgresql) (6.1) or use an Amazon RDS Service for your PostgreSQL database (6.2) or Azure Database for PostgreSQL (6.3).  

6.1.1. PostgreSQL Helm chart installation

To use this type of installation, please run the following commands:
```sh
helm dependency build ./reportportal/
```

```sh
helm install <postgresql_chart_name> --set postgresqlUsername=rpuser,postgresqlPassword=<rpuser_password>,postgresqlDatabase=reportportal,postgresqlPostgresPassword=<postgres_password> -f ./reportportal/postgresql/values.yaml ./reportportal/charts/postgresql-8.6.2.tgz
```
At the last command:
* postgresql_chart_name - a name of your DB deployment inside a cluster
* postgresqlPassword - is a password for a user which will be used by ReportPortal to connect to the database
* postgresqlPostgresPassword - is a password for 'postgres' user, which is a superuser for your PostgreSQL instanse. You can omit this value and then the chart will generate it for you

> Please be aware of api deprecations in Kubernetes 1.16.  
It can cause the following issue on some Helm charts: Error: validation failed: unable to recognize "": no matches for kind "StatefulSet" in version "apps/v1beta1.
The issue is coming from the 3rd party dependencies which listed deprecated API versions.
As a workaround, please use [compatible versions of Kubernetes](https://github.com/reportportal/kubernetes#requirements). 

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

After PostgreSQL is up and running, edit values.yaml to adjust the settings  

Insert the real values of PostgreSQL address and ports:  

> Since you go with the PostgreSQL Helm chart option, you do not need to set the db password in the 'password' value here, because it has been already set above with "helm install .." command

```yaml
postgresql:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    cloudservice: false
    address: <postgresql_chart_name>-postgresql.default.svc.cluster.local
    port: 5432
    user: rpuser
    dbName: reportportal
    password:
```

6.2. PostgreSQL as an external cloud service. Amazon RDS PostgreSQL

6.2.1. Provision an Amazon RDS PostgreSQL instance with the created 'rpuser' user and 'reportportal' database

Creation of ReportPortal data in PostgreSQL db required the ltree extension installation. This, in turn, required the 'rpuser' to have a super user access

> If you are using AWS EKS to run Kubernetes for ReportPortal please be sure to follow the steps 6.1.1 - 6.1.2

6.2.1.1
Choose your EKS VPC in 'Network & Security' advanced settings.
Otherwise, you will need to create a peering connection from the RDS VPC to the EKS VPC, and update the routing tables for both of VPCs. For the EKS routing table a new route should be created with a destination which corresponds to CIDR IP of RDS VPC, and the peering connection as a target. Similarly, you need to create a new route for the RDS routing table

6.2.1.2
You can choose your EKS VPC security groups, or add a new rule in the RDS security group which allows all traffic from EKS CIDR IP

6.2.1.3
In case a peering connection created, go to it and change its configuration by enabling a DNS propagation
(When you use the RDS DNS name inside the same VPC it will be resolved to a Private IP itself)

6.2.2. Accessing your RDS

To list the details of your Amazon RDS DB instance, you can use the AWS Management Console, the AWS CLI describe-db-instances command, or the Amazon RDS API DescribeDBInstances action.
You need the following information to connect:
  * The host or host name for the DB instance ;
  * The port on which the DB instance is listening. For example, the default PostgreSQL port is 5432 ;
  * The user name and password

a) Open ReportPortal Helm chart values.yaml and set 'cloudservice' value in postgresql section from 'false' to 'true'. This allows you to use PostgreSQL as an external cloud service    

```yaml
postgresql:
..
    cloudservice: true
..
```

b) Write down the real values into the corresponding section of values.yaml with your PostgreSQL address, port, dbName and password:  

> The db password can be also skipped here if you're going to override it on the stage of ReportPortal Helm chart deploy  

```yaml
postgresql:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    cloudservice: true
    address: <postgresql address>
    port: 5432
    user: rpuser
    dbName: reportportal
    password: <postgresql password>
```

6.3. PostgreSQL as an external cloud service. Azure Database for PostgreSQL  

6.3.1. Creation an Azure Database for PostgreSQL server  

You can create an Azure Database for PostgreSQL server in the [Azure portal](https://docs.microsoft.com/en-us/azure/postgresql/quickstart-create-server-database-portal) or using the [Azure CLI](https://docs.microsoft.com/en-us/azure/postgresql/quickstart-create-server-database-portal)  

For the best performance we strongly recommend you to use the 'General Purpose' compute and storage configurations  

6.3.2. Configuration a server-level firewall rules    

In the Azure portal go to the created Azure Database for PostgreSQL server, Settings - Connection security  

6.3.2.1

> If you run your Kubernetes cluster in Azure AKS  

Allow access to Azure services - set to 'Yes'  
You can also tweak this more finely by using the firewall rules (see below)

> If you run your Kubernetes cluster outside of Azure AKS or want to tweak this more finely

Under the Firewall rules, in the Rule Name column, select the blank text box to begin creating the firewall rule.  
Fill in the text boxes with a name, and the start and end IP range of the clients that will be accessing your server (it must be all of your Kubernetes Worker nodes, at minimum).  
If it is a single IP, use the same value for the start IP and end IP
On the upper toolbar of the Connection security page, select Save. Wait until the notification appears stating that the connection security update has finished successfully before you continue

6.3.2.2

Under the SSL settings,
Enforce SSL connection - set to 'Disabled'

6.3.3. Creation 'reportportal' database

After your Azure PostgreSQL server is ready and you able to connect, get the connection information (server name and login) on the server Overview page in the portal.  

Run the following psql command to connect to an Azure Database for PostgreSQL server  
```sh
psql --host=<servername> --port=<port> --username=<user@servername> --dbname=<dbname>
```

Create a blank database called 'reportportal
```sh
CREATE DATABASE reportportal;
```

Execute the following command to switch connections to the newly created database
```sh
\c reportportal
```

Type \q, and then select the Enter key to quit psql

6.3.4. Accessing your Azure Database for PostgreSQL server

You need the following information to connect:
  * The server name;
  * The Admin username and password

a) Open ReportPortal Helm chart values.yaml and set 'cloudservice' value in postgresql section from 'false' to 'true'. This allows you to use PostgreSQL as an external cloud service    

```yaml
postgresql:
..
    cloudservice: true
..
```

b) Write down the real values into the corresponding section of values.yaml with your PostgreSQL address, port, dbName and password:  

> The db password can be also skipped here if you're going to override it on the stage of ReportPortal Helm chart deploy  

```yaml
postgresql:
  SecretName: ""
  installdep:
    enable: false
  endpoint:
    cloudservice: true
    address: <postgresql address>
    port: 5432
    user: <Admin username>
    dbName: reportportal
    password: <postgresql password>
```

#### 7. MinIO installation

MinIO is a high performance distributed object storage server and a preferable way of using our file storage. It stays on top of S3 or any other cloud storage, and allows to have a shared FS for several API and UAT pods in Kubernetes.  

The following command will install Minio with 40GB PVC:  

```sh
helm install minio --set accessKey=<your_minio_accesskey>,secretKey=<your_minio_secretkey>,persistence.size=40Gi stable/minio
```

Installation output example  
```
Minio can be accessed via port 9000 on the following DNS name from within your cluster:
minio.default.svc.cluster.local

To access Minio from localhost, run the below commands:

  1. export POD_NAME=$(kubectl get pods --namespace default -l "release=minio" -o jsonpath="{.items[0].metadata.name}")

  2. kubectl port-forward $POD_NAME 9000 --namespace default

Read more about port forwarding here: http://kubernetes.io/docs/user-guide/kubectl/kubectl_port-forward/

You can now access Minio server on http://localhost:9000. Follow the below steps to connect to Minio server with mc client:

  1. Download the Minio mc client - https://docs.minio.io/docs/minio-client-quickstart-guide

  2. mc config host add minio-local http://localhost:9000 testaccesskey testsecretkey S3v4

  3. mc ls minio-local

Alternately, you can use your browser or the Minio SDK to access the server - https://docs.minio.io/categories/17
```

Do not forget to update corresponding section of values.yaml with your endpoint, secret and access keys:  

```yaml
minio:
  enabled: true
  installdep:
    enable: false
  endpoint: http://<minio-release-name>.default.svc.cluster.local:9000
  region:
  accesskey: <minio-accesskey>
  secretkey: <minio-secretkey>
```

You can also use Amazon S3 storage instead of self-hosted MinIO's storage through passing S3 endpoint and IAM user access key ID and secret to the RP_BINARYSTORE_MINIO_* env variables, which can be defined via the same parameters in values.yaml.  

Configuration of MinIO AWS storage region for binary storage must be defined via 'region' value in this case.  

Example

```yaml
minio:
  enabled: true
..
  region: us-east-1
..
```

#### 8. (OPTIONAL) Additional adjustments

Adjust resources requests/limits in values.yaml for each pod if needed:  

```yaml
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 512Mi
```

If you are going to associate a specific DNS name with your UI, set Ingress controller configuration like this:  

```yaml
# ingress configuration for the ui
ingress:
..
  usedomainname: true
  hosts:
    - <Your DNS name>
..
```

You can also set total amount of RabbitMQ queues, and their number for each API service pod by changing serviceapi.queues.totalNumber and serviceapi.queues.perPodNumber parameters (10 and 10 by default). The general rule here is "queues.totalNumber = number_of_api_pods * queues.perPodNumber"

```yaml
serviceapi:
..
  queues:
    totalNumber: 
    perPodNumber: 
```

#### 9. Deploy the ReportPortal Helm Chart

Once everything is ready, the ReportPortal Helm chart can be packaged into a chart archive and deployed by executing the following commands:

```sh
helm package ./reportportal/
```

> If you use PostgreSQL Helm chart  

```sh
helm install <reportportal_chart_name> --set postgresql.SecretName=<db_chart_name>-postgresql,rabbitmq.SecretName=<rabbitmq_chart_name> ./reportportal-5.tgz
```

> If you use Amazon RDS PostgreSQL instance / Azure Database for PostgreSQL / (an external database)
> You can also override the specified 'rpuser' user password in values.yaml, by passing it as a parameter in this install command line  

```sh
helm install <reportportal_chart_name> --set postgresql.endpoint.password=<postgresql_dbuser_password>,rabbitmq.SecretName=<rabbitmq_chart_name> ./reportportal-5.tgz
```

#### 10. Validate the pods and service

Once ReportPortal is deployed, you can validate if the application is up and running by:

1. Check the pods status:  

```sh
kubectl get pods
```

Everything should be in "Running" status, and 'migrations' service in "Completed"  

2. Open your LoadBalancer address in a web browser

Since you expose your application with an Ingress controller, note LoadBalancer's EXTERNAL-IP address by run:  

```sh
kubectl get service
```

As an example, if you have:  
```sh
my-nginx-nginx-ingress-controller  LoadBalancer 10.100.69.32  af1010eb94bce011e9bb3306ea08f1137-459046881.eu-central-1.elb.amazonaws.com  80:32633/TCP,443:31683/TCP  2s
```

Then http://af1010eb94bce011e9bb3306ea08f1137-459046881.eu-central-1.elb.amazonaws.com is your RP UI address

#### 11. Start work with ReportPortal 

Open the http://<LoadBalancer's EXTERNAL-IP address> page in your browser. Defalut login and password are:  

```
default
1q2w3e
```

P.S: If you can't login - please check logs of api and uat pods. It take some time to initialize


### Updating ReportPortal to the latest version  

Generally, updating ReportPortal in Kubernetes is a two step process.  

#### 1. Update values.yaml

In the first step, your helm chart values.yaml file should be updated with the latest version of services (see values `repository` and `tag`).  

The following services should be taken into consideration:  
- serviceindex
- uat
- serviceui
- serviceapi
- migrations
- serviceanalyzer  

#### 2. Update the application  

The second step is update / redeploy the application using the following commands:  

> If you use PostgreSQL Helm chart  

```sh
helm upgrade -f reportportal/values.yaml --set --set postgresql.SecretName=<db_chart_name>-postgresql,rabbitmq.SecretName=<rabbitmq_chart_name> <reportportal_chart_name> ./reportportal-5.tgz
```

> If you use Amazon RDS PostgreSQL instance / Azure Database for PostgreSQL / (an external database)

```sh
helm upgrade -f reportportal/values.yaml --set postgresql.endpoint.password=<postgresql_dbuser_password>,rabbitmq.SecretName=<rabbitmq_chart_name> <reportportal_chart_name> ./reportportal-5.tgz
```

#### IMPORTANT  

Before you start updating your application, please check release notes at the [reportportal wiki](https://github.com/reportportal/reportportal/wiki)!  
Sometimes, ReportPortal update may require recreation / cleaning of its dependencies (e.g. RabbitMQ), or any other additional actions.  


### Run ReportPortal over SSL (HTTPS)

#### 1. Configure a custom domain name for your ReportPortal website

Set up a domain name you own at the domain registrar  

#### 2. Pre-requisite configuration

In order to enable HTTPS, you need to get a SSL/TLS certificate from a Certificate Authority (CA)  
As a free option, you can use Let's Encrypt - a non-profit TLS CA. Its purpose is to try to make a safer internet by making it easier and cheaper to use TLS  

#### 2.1. Deploy the Cert Manager

[Cert-manager](https://github.com/jetstack/cert-manager/tree/master/deploy/charts/cert-manager) is a native Kubernetes certificate management controller  
It can help with issuing certificates from a variety of sources, such as Let’s Encrypt, HashiCorp Vault, Venafi, a simple signing keypair, or self-signed  

Install the cert-manager CRDs **before** installing the cert-manager Helm

```sh
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.3/cert-manager.crds.yaml
```

Add the Jetstack Helm repository

```sh
$ helm repo add jetstack https://charts.jetstack.io && helm repo update
```

Install the cert-manager

```sh
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.0.3
```

#### 2.2. Create a Let's Encrypt CA ClusterIssuer Kubernetes resource:
 
 ClusterIssuers (and Issuers) represent a certificate authority from which signed x509 certificates can be obtained, such as Let’s Encrypt. You will need at least one ClusterIssuer in order to begin issuing certificates within your cluster  

```sh
vi letsencrypt-clusterissuer.yaml
```

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: <your_clusterissuer_name>
spec:
  acme:
    email: <your_email>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: <your_clusterissuer_name>-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

Do not forget to set the name and email for your ClusterIssuer   

For example  
```yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: support@testreportportal.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

```sh
kubectl create -f letsencrypt-clusterissuer.yaml
```

#### 3. Update your ReportPortal installation with a new Ingress Configuration to be access at a TLS endpoint

With all the pre-requisite configuration in place, we can now do the pieces to request the TLS certificate  

#### 3.1. Add the certmanager annotation:

Add the following annotation to your Ingress configuration by editing ReportPortal Helm chart values.yaml file  

```
cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

The result in values.yaml  

```yaml
..
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/x-forwarded-prefix: /$1
    nginx.ingress.kubernetes.io/proxy-body-size: 128m
    nginx.ingress.kubernetes.io/proxy-buffer-size: 512k
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
    nginx.ingress.kubernetes.io/proxy-busy-buffers-size: 512k
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "2000"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "1000"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "1000"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

#### 3.2. Update your ReportPortal Ingress configuration:

Edit gateway-ingress.yaml template in your copy of ReportPortal Helm chart, and add the following right after 'spec'  

```yaml
  tls:
  - hosts:
    - <your_domain_name>
    secretName: <your_certificate_secretname>
```
> You will create your certificate with secretname on the next step  

Let's suppose your domain name is 'my.reportportal.com' and your certificate secretname is 'my.reportportal.com-tls'  

Then the result in your gateway-ingress.yaml file will be  

```yaml
spec:
  tls:
  - hosts:
    - my.reportportal.com
    secretName: my.reportportal.com-tls
  rules:
..
```

#### 3.3. Redeploy or upgrade your ReporPortal installation with Helm


#### 4. Create a Certificate resource in Kubernetes with acme http challenge configured:   

```sh
vi certificate-tls.yaml
```

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: <your_certificate_name>
spec:
  secretName: <your_certificate_secretname>
  dnsNames:
  - <your_domain_name>
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - <your_domain_name>
  issuerRef:
    name: <your_clusterissuer_name>
    kind: ClusterIssuer
```

For our example  
```yaml 
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

```sh
kubectl create -f certificate-tls.yaml
```

Once this resource is created, there should be a tls cert that is created. If not, then check the logs of the cert-manger service for errors  

In order to check the certificate and secret  

```
kubectl get certificates
kubectl describe certificate <your_certificate_name>
```

```
kubectl get secrets
kubectl describe secret <your_certificate_secretname>
```

Now you should be able to run your ReportPortal installation over HTTPS  

Please take into account that you don't have to re-deploy the application in order to apply changes