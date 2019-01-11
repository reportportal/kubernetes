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
- mongodb: mongodb 3.4
- consul: consul 1.0.6
- serviceauthorization: reportportal/service-authorization 4.1.0
- serviceui: reportportal/service-ui 4.1.0
- serviceanalyzer: reportportal/service-analyzer 4.1.0
- serviceapi:  reportportal/service-api 4.1.0
- elasticsearchoss: docker.elastic.co/elasticsearch/elasticsearch-oss  6.1.1

Requirements:
- mongodb
- elasticsearch

Before you deploy reportportal you should have installed requirements. Versions are described in requirements.yaml.
Also you should specify correct mongodb and elasticsearch addresses and ports in values.yaml. Also it could be an external existing installation:
`elasticsearch:
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
    port: 27017`
