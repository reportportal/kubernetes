# Aggregator-k8s
Kubernetes/Helm configs for Aggregator

**Do note that this is a Beta version**


This Helm project is created to setup ReportPortal with only one commando.  
The help chart is tested on Minikube and creates a fully working ReportPortal project

The chart installs all mandatory services to run ReportPortal

The Helm chart installation consist of the following .yaml files:

- Statefulset and Service files of: `Aggregator` that are used for deployment and communication between services.
- A `Ingress` to access the EndPoint
- A `values.yaml` which exposes a few of the configuration options in the
charts.
- A `templates/_helpers.tpl` file which contains helper templates. 

Start to minikube with options:
- `minikube start`

Installation of ingress plugin:
- `minikube addons enable ingress`

For deploy Helm Chart, need to initialization Helm:
- `helm init`

You can deploy this chart with `helm install ./<project folder>`. 

Once it's installed please make sure that the PersistentVolumes directories are created

The url to reach ReportPortal is http://status.reportportal.io
Make sure that the url is added in the host file and the ip is the K8 ip address
Commando to get ip adress of minikube:
- `minikube ip`

The url to reach ReportPortal is http://reportportal.k8.com
Make sure that the url is added in the host file and the ip is the K8 ip address
Example:
- `192.168.99.100	status.reportportal.io`

Variables is presents in value.yml. Report Portal use next images in variables:

- PORT: 
- TWITTER_CONSUMER:
- TWITTER_CONSUMER_SECRET:
- TWITTER_TOKEN:
- TWITTER_TOKEN_SECRET:
- TWITTER_BUFFER_SIZE: 
- TWITTER_SEARCH_TERM: 
- GITHUB_INCLUDE_BETA: 
- GITHUB_TOKEN:
- GOOGLE_API_KEY