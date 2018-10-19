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


You can deploy this chart with `helm install ./<project folder>`. 

Once it's installed please make sure that the PersistentVolumes directories are created

Commando to create those folders:
- `minikube ssh`
- `sudo mkdir -p /mnt/data/db`
- `sudo mkdir -p /mnt/data/console`
- `sudo mkdir -p /mnt/data/elastic`

Also make sure that the vm.max_map_count is setup
- `minikube ssh`
- `sudo sysctl -w vm.max_map_count=262144`

The url to reach ReportPortal is http://reportportal.k8.com
Make sure that the url is added in the host file and the ip is the K8 ip address
Example:
- `192.1.1.1	reportportal.k8.com`

Variables is presents in value.yml. Report Portal use next images in variables:

- fabio: fabiolb/fabio 1.5.8-go1.10 
- serviceindex:  reportportal/service-index 4.0.0
- mongodb: mongodb 3.4
- consul: consul 1.0.6
- serviceauthorization: reportportal/service-authorization 4.1.0
- serviceui: reportportal/service-ui 4.1.0
- serviceanalyzer: reportportal/service-analyzer 4.1.0
- serviceapi:  reportportal/service-api 4.1.0
- elasticsearchoss: docker.elastic.co/elasticsearch/elasticsearch-oss  6.1.1
  