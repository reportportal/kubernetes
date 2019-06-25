# K8s
Kubernetes Helm config for installation ReportPortal on AWS with an Amazon RDS as a database

**Overall information**

This Helm project is created to install all mandatory services to run ReportPortal on AWS with only one commando, but it implies that an external Amazon RDS Service for PostgreSQL should be used.

The chart installation consist of the following .yaml files:

- Statefulset and Service files of: `Analyzer, Api, Index, Migrations, UAT, UI` that are used for deployment and communication between services
- `Ingress` objects to access the UI
- `values.yaml` which exposes a few of the configuration options in the charts
- `templates/_helpers.tpl` file which contains helper templates.

ReportPortal use the following images in variables:

- serviceindex: pbortnik/rp5-index
- uat: pbortnik/rp5-uat
- serviceui: pbortnik/rp5-ui
- serviceapi: pbortnik/rp5-api
- migrations: pbortnik/rp5-migrations
- serviceanalyzer: pbortnik/rp5-analyzer

Requirements: 

- `RabbitMQ`
- `ElasticSearch`
- `PostgreSQL` (Amazon PostgreSQL RDS)

Before you deploy ReportPortal you should have installed all requirements & deploy your Amazon PostgreSQL RDS.

All variables are presented in the value.yaml file

### Installation notes

1. Prepare your Kubernetes cluster and make sure it's up and running

There are two options to use Kubernetes on AWS:
- `Manage Kubernetes infrastructure yourself with Amazon EC2`
- `Get an automatically provisioned, managed Kubernetes control plane with Amazon EKS`

We recommend you to go with the second option, and use Amazon EKS.

To create and configure your AWS EKS Cluster you can use either the AWS console or AWS CLI -> [Instruction](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

2. Install and configure Helm package manager 

For more information about installation the Helm package manager on your AWS EKS cluster, see the following [Guide](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)

You can test your Helm configuration by installing a simple Helm chart like a Wordpress
```
$ helm install stable/wordpress
```
Do not forget to clean up the wordpress chart resources after making sure everything works as expected

3. Deploy Ingress controller if you need to expose your application

Please find the [Instruction](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#aws)

4. ReportPortal requires installed [elasticsearch](https://github.com/elastic/helm-charts/tree/master/elasticsearch) and [rabbitmq](https://github.com/helm/charts/tree/master/stable/rabbitmq-ha) to run the application

To install Elasticsearch chart please use this commands:
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

5. After ElasticSearch and RabbitMQ are up and running, edit values.yaml to adjust ReportPortal settings

Insert the real values of ElasticSearch and RabbitMQ addresses and ports:
```
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
    - <YOUR_DNS_NAME>
```

6. Connection to your Amazon RDS PostgreSQL instance

6.1. Provision an Amazon RDS PostgreSQL instance with the created 'rpuser' user and 'reportportal' database

Creation of ReportPortal data in PostgreSQL db required the ltree extension installation. This, in turn, required the 'rpuser' to have a super user access

> If you are using AWS EKS to run Kubernetes for ReportPortal please be sure to follow the steps 6.1.1 - 6.1.3

6.1.1
Choose your EKS VPC in 'Network & Security' advanced settings.
Otherwise, you will need to create a peering connection from the RDS VPC to the EKS VPC, and update the routing tables for both of VPCs. For the EKS routing table a new route should be created with a destination which corresponds to CIDR IP of RDS VPC, and the peering connection as a target. Similarly, you need to create a new route for the RDS routing table

6.1.2
You can choose your EKS VPC security groups, or add a new rule in the RDS security group which allows all traffic from EKS CIDR IP

6.1.3
In case a peering connection created, go to it and change its configuration by enabling a DNS propagation
(When you use the RDS DNS name inside the same VPC it will be resolved to a Private IP itself)

6.2. Accessing your RDS

To list the details of your Amazon RDS DB instance, you can use the AWS Management Console, the AWS CLI describe-db-instances command, or the Amazon RDS API DescribeDBInstances action.
You need the following information to connect:
  * The host or host name for the DB instance ;
  * The port on which the DB instance is listening. For example, the default PostgreSQL port is 5432 ;
  * The user name and password

Write down the real values of PostgreSQL address, port, dbName and password into the values.yaml.
The db password can be skipped here if you're going to override it on the next step.

```sh
postgresql.endpoint.address = 
postgresql.endpoint.port = 5432
postgresql.endpoint.user = rpuser
postgresql.endpoint.dbName = reportportal
postgresql.endpoint.password = 
```

7. Once everything is ready, the ReportPortal Helm chart package can be created and deployed by executing:

(You can override the specified 'rpuser' user password in values.yaml, by passing it as a parameter in this install command line)

```sh
helm package ./reportportal/
```
```sh
helm install --name <reportportal_chart_name> --set postgresql.endpoint.password=<postgresql_dbuser_password>,rabbitmq.SecretName=<rabbitmq_chart_name>-rabbitmq-ha ./reportportal-5.0-SNAPSHOT.tgz
```

8. Once ReportPortal is deployed, you can validate application is up and running by opening your NodePort / Ingress address server:

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

In case you use AWS Classic Load Balancer, please follow this [Instruction](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/using-domain-names-with-elb.html)

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




