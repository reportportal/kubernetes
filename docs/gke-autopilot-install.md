# Install ReportPortal on GKE Cluster

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
gcloud container clusters get-credentials cluster-rp-helm --zone us-central1-c --project or2-msq-epm-rpp-b2iylu
```

## Install on GKE Autopilot Cluster

```bash
helm install \
    --set ingress.class="gke" \
    --set uat.superadminInitPasswd.password="erebus" \
    --set uat.resources.requests.cpu="500m" \
    --set uat.resources.requests.memory="1Gi" \
    --set serviceapi.resources.requests.cpu="1000m" \
    --set serviceapi.resources.requests.memory="2Gi" \
    --set serviceanalyzer.resources.requests.memory="1Gi" \
    reportportal \
    oci://us-central1-docker.pkg.dev/or2-msq-epm-rpp-b2iylu/reportportal-helm-repo/reportportal \
    --version 23.2.1-develop
```

## Install on GKE Standard Cluster

https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster#gcloud

```bash
gcloud container clusters create example-cluster \
    --zone us-central1-a \
    --machine-type=e2-standard-2 --num-nodes=3
```

```bash
helm install \
    --set ingress.class="gke" \
    --set uat.superadminInitPasswd.password="erebus" \
    reportportal \
    oci://us-central1-docker.pkg.dev/or2-msq-epm-rpp-b2iylu/reportportal-helm-repo/reportportal \
    --version 23.2.1-develop
```
