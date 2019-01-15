# k8s
Kubernetes/Helm configs for ReportPortal

**Do note that this is a Beta version**


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
- `minikube --memory 4096 --cpus 2 start`

Installation of ingress plugin:
- `minikube addons enable ingress`

For deploy Helm Chart, need to initialization Helm:
- `helm init`

You can deploy this chart with `helm install ./<project folder>`. 

Once it's installed please make sure that the PersistentVolumes directories are created

Commando to create those folders:
- `minikube ssh`
- `sudo mkdir /mnt/data/db`
- `sudo mkdir /mnt/data/console`
- `sudo mkdir /mnt/data/elastic`

Also make sure that the vm.max_map_count is setup
- `minikube ssh`
- `sudo sysctl -w vm.max_map_count=262144`

The url to reach ReportPortal is http://reportportal.k8.com
Make sure that the url is added in the host file and the ip is the K8 ip address
Commando to get ip adress of minikube:
- `minikube ip`
Example for host file:
- `192.168.99.100	reportportal.k8.com`

Variables is presents in value.yml. Report Portal use next images in variables:

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
```
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

### Installation notes
1. Make sure you have Kubernetes up and running
2. Reportportal requires installed [mongodb](https://github.com/helm/charts/tree/master/stable/mongodb) and [elasticsearch](https://github.com/helm/charts/tree/master/stable/elasticsearch) to run. Required versions of helm charts are described in requirements.yaml
If you don't have your own mongodb and elasticsearch instances, they can be installed from official helm charts. 

For example to install mongodb please use this commands:
```sh
helm dependency build ./reportportal/
helm install --name <chart_name> ./reportportal/charts/mongodb-0.4.18.tgz
```
Once MongoDB has been deployed, copy address and port from output notes. Should be something like this:
```
NOTES:
MongoDB can be accessed via port 27017 on the following DNS name from within your cluster:
<chart_name>-mongodb.default.svc.cluster.local
```
Elasticsearch chart should be installed in the same manner:
```sh
helm install --name <chart_name> ./reportportal/charts/elasticsearch-1.17.0.tgz
```

3. After mongodb and elasticsearch up and running you should edit values.yaml to adjust reportportal settings.
Insert real values of mongodb and elasticsearch addresses and ports:
```
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
```
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 512Mi
```
Set persistence configuration and storage capacity for registry:
```
persistence:
  registry:
    enabled: true
...
```
Set ingress controller configuration for UI like this:
```
# ingress configuration for the ui
ingress:
  hosts:
    - reportportal.k8.com
```
4. After you edited and reviewed values.yaml with appropriate values you could create helm package and deploy it:
```sh
helm package ./reportportal/
helm install ./reportportal-4.3.6.tgz
```
When it up and running you can access application from your browser with NodePort or ingress address.
```example
gateway     NodePort   10.233.48.187  <none>       80:31826/TCP,8080:31135/TCP  2s
```
5. Open in browser http://10.233.48.187:8080 page. Defalut login and password is:
```
default
1q2w3e
```
P.S: If you can't login - please check logs of api and uat pods. It take some time to initialize.
