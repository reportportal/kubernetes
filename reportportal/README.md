# k8s

## Kubernetes/Helm configs for ReportPortal

**Important** Do note that this is **a Beta version**

This Helm project is created to setup ReportPortal with only one commando.
The help chart is tested on Minikube and creates a fully working ReportPortal project

The chart installs all mandatory services to run ReportPortal

The Helm chart installation consist of the following .yaml files:

- Statefulset and Service files of: `Analyzer, Api, Elasticsearch, Gateway, Index, Mongodb, Registry, UAT, UI` that are used for deployment and communication between services.
- PersistentVolume files: `Elasticsearch, Mongodb, Registry`
- A `Ingress` to access the UI
- A `values.yaml` which exposes a few of the configuration options in the
charts.
- A `templates/_helpers.tpl` file which contains helper templates.

Start to minikube with options:

- `minikube --memory 12228 --cpus 2 start`

Installation of ingress plugin:

- `minikube addons enable ingress`

For deploy Helm Chart, need to initialization Helm:

- `helm init`

You can deploy this chart with `helm install ./<project folder>`.

Once it's installed please make sure that the PersistentVolumes directories are created

Commando to create those folders:

```bash
minikube ssh
sudo mkdir /mnt/data/db -p
sudo mkdir /mnt/data/console -p
sudo mkdir /mnt/data/elastic -p
```

Also make sure that the vm.max_map_count is setup

```bash
minikube ssh
sudo sysctl -w vm.max_map_count=262144
```

The url to reach ReportPortal is http://reportportal.k8.com
Make sure that the url is added in the host file and the ip is the K8 ip address

Commands to get ip adress of minikube:

`minikube ip`

Example for host file:

`192.168.99.100	reportportal.k8.com`

Variables is presents in value.yml. Report Portal uses the next images in variables:

- traefik: traefik 1.6
- serviceindex:  reportportal/service-index 4.0.0
- consul: consul 1.0.6
- serviceauthorization: reportportal/service-authorization 4.1.0
- serviceui: reportportal/service-ui 4.1.0
- serviceanalyzer: reportportal/service-analyzer 4.1.0
- serviceapi:  reportportal/service-api 4.1.0

Requirements:

- `mongodb`
- `elasticsearch`

Before you deploy reportportal you should have installed requirements. Versions are described in requirements.yaml.
Also you should specify correct mongodb and elasticsearch addresses and ports in values.yaml. Also it could be an external existing installation:

```yaml
elasticsearch:
  installdep:
    enable: false
  endpoint:
    external: true
    address: elasticsearch-client.default.svc
    port: 9200
mongodb:
  installdep:
    enable: false
  endpoint:
    external: true
    address: mongodb://mongodb.default.svc.cluster.local
    port: 27017
```

## Installation notes

1. Make sure you have Kubernetes up and running
1. Reportportal requires installed [mongodb](https://github.com/helm/charts/tree/master/stable/mongodb) and [elasticsearch](https://github.com/helm/charts/tree/master/stable/elasticsearch) to run. Required versions of helm charts are described in requirements.yaml
If you don't have your own mongodb and elasticsearch instances, they can be installed from official helm charts.

    For example to install mongodb please use this commands:

    ```sh
    helm dependency build ./reportportal/
    helm install --name <chart_name> --set mongodbUsername=<mongo_user_name>,mongodbPassword=<user_password> ./reportportal/charts/mongodb-0.4.18.tgz
    ```

    Once MongoDB has been deployed, copy address and port from output notes. Should be something like this:

    ```sh
    NOTES:
    MongoDB can be accessed via port 27017 on the following DNS name from within your cluster:
    <db_chart_name>-mongodb.default.svc.cluster.local
    ```

    Elasticsearch chart can be installed in the same manner:

    ```sh
    helm install --name <es_chart_name> ./reportportal/charts/elasticsearch-1.17.0.tgz
    ```

1. After mongodb and elasticsearch are up and running, edit values.yaml to adjust ReportPortal settings.
Insert real values of mongodb and elasticsearch addresses and ports:

    ```yaml
    elasticsearch:
      installdep:
        enable: false
      endpoint:
        external: true
        address: <chart_name>-elasticsearch-client.default.svc
        port: 9200
    mongodb:
      installdep:
        enable: false
      endpoint:
        external: true
        address: mongodb://<chart_name>-mongodb.default.svc
        port: 27017
    ```

    Adjust resources for each pod if needed:

    ```yaml
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 512Mi
    ```

    Set ingress configuration for UI and adjust settings if you have installed ingress controller.:

    ```yaml
    # ingress configuration for the ui
    # If you have installed ingress controller and want to expose application - set INGRESS.ENABLE to true.
    # If you have some domain name set INGRESS.USEDOMAINNAME variable to true and set this fqdn to INGRESS.HOSTS
    # If you don't have any domain names - set INGRESS.USEDOMAINNAME to false
    ingress:
      enable: true
      # IF YOU HAVE SOME DOMAIN NAME SET INGRESS.USEDOMAINNAME to true
      usedomainname: false
      hosts:
        - reportportal.k8.com
    ```

1. Once values.yaml is adjusted, helm package can be created and deployed by executing:

    ```sh
    helm package ./reportportal/
    helm install --name <app_chart_name> --set mongoSecretName=<mongo_chart_name>-mongodb,mongodb.endpoint.address=<db_chart_name>-mongodb.default.svc.cluster.local,mongodb.endpoint.username=<mongo_user_name>,mongodb.endpoint.dbname=<mongodb_reportportal_dbname> ./reportportal-4.3.6.tgz
    ```

    Once deployed, you can validate application is up and running by opening your ingress address server or NodePort:

    ```sh
    gateway     NodePort   10.233.48.187  <none>       80:31826/TCP,8080:31135/TCP  2s
    ```

1. Open in browser http://10.233.48.187:8080 page. Defalut login and password can be:

    - default / 1q2w3e
    - superadmin / erebus

    **Note**: If you can't login - please check logs of api and uat pods. It takes some time to initialize.

## Microsoft Azure AKS deployment notes

1. Deploy an Azure Kubernetes Service (AKS) cluster using the Azure portal or cli -> [instruction](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough-portal)
1. Make sure you have AKS cluster up and running
1. Configure Helm package manager on your AKS cluster -> [instruction](https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm)
1. Deploy ingress controller if you need to expose your allpication -> [instruction](https://docs.microsoft.com/en-us/azure/aks/ingress-basic)
1. Deploy dependencies and application according to installation notes
1. Get nginx-ingress-controller LoadBalancer's EXTERNAL-IP address with command

    ```sh
    kubectl get services
    NAME				TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                       AGE
    nginx-ingress-controller	LoadBalancer   10.0.132.176   40.114.87.240   80:32763/TCP,443:30295/TCP    2m38s
    ```

1. Open it in your browser http://40.114.87.240

## Amazon EKS deployment notes

### Prerequisites

1. Create and configure AWS EKS Cluster. You can use either the AWS console or AWS CLI -> [Instruction](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

1. Install and configure Helm package manager on your AWS AKS cluster -> [Instruction](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)

    You can test your Helm configuration by installing a simple Helm chart like a Wordpress

    ```sh
    helm install stable/wordpress
    ```

    Do not forget to clean up the wordpress chart resources after making sure everything works as expected

### Installation

1. Deploy Ingress controller if you plan to expose your application -> [Instruction](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md#aws)

1. Proceed with the Installation notes at https://github.com/reportportal/kubernetes/tree/master/reportportal#installation-notes
(The steps before it can be ignored )

1. Run the next command to get LoadBalancer's EXTERNAL-IP address:

    ```sh
    kubectl get svc
    ```

1. Open http://EXTERNAL-IP  in your browser to see if the dashboard is available
