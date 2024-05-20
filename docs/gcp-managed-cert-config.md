# Use Google-managed SSL certificates

- [Use Google-managed SSL certificates](#use-google-managed-ssl-certificates)
  - [Limitations](#limitations)
  - [Before you begin](#before-you-begin)
  - [Add a Google-managed SSL via Helm chart](#add-a-google-managed-ssl-via-helm-chart)
  - [Manual adding a Google-managed SSL certificate](#manual-adding-a-google-managed-ssl-certificate)
    - [Setting up a Google-managed certificate](#setting-up-a-google-managed-certificate)
      - [Create a `ManagedCertificate` resource](#create-a-managedcertificate-resource)
      - [Update the Ingress resource](#update-the-ingress-resource)
  - [Check the status of the certificate](#check-the-status-of-the-certificate)
    - [Using kubectl](#using-kubectl)
    - [Using the Google Cloud CLI](#using-the-google-cloud-cli)
  - [Disable HTTP Load Balancing](#disable-http-load-balancing)
  - [Clean up](#clean-up)

You can use Google-managed SSL certificates to secure your custom domain with HTTPS.
Google-managed SSL certificates are provisioned, renewed, and managed for your domain by Google.
You can use Google-managed SSL certificates with Google Kubernetes Engine (GKE) and Google Cloud Load Balancing.

Comprehensive documentation is available at [Google-managed SSL certificates](https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs).

## Limitations

- Don't support wildcard domains.
- The domain name must be no longer than 63 characters.
- Your ingressClassName must be "gce".
- You must apply Ingress and ManagedCertificate resources in the same project and namespace.

## Before you begin

- [Install the Google Cloud CLI](https://cloud.google.com/sdk/docs/install).
- [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- [Set up default gcloud settings](https://cloud.google.com/sdk/gcloud/reference/init).
- [Set up Environment Variables](./quick-start-gcp-gke.md#set-up-environment-variables).
- [Get cluster credentials for kubectl](./quick-start-gcp-gke.md#get-cluster-credentials-for-kubectl)

## Add a Google-managed SSL via Helm chart

To add a Google-managed SSL certificate to your ReportPortal deployment,
you need to set the following parameters:

```bash
helm install \
...
  --set ingress.tls.certificate.gcpManaged=true
  --set ingress.hosts[0]="example.com"
...

```

Helm creates a `ManagedCertificate` resource and an `Ingress` resource that references the `ManagedCertificate` resource.

GKE automatically provisions the certificate and configures the load balancer to use it.

## Manual adding a Google-managed SSL certificate

### Setting up a Google-managed certificate

#### Create a `ManagedCertificate` resource

Create a `ManagedCertificate` resource in gcp-managed-cert.yaml to request a Google-managed SSL certificate for your domain.

```yaml
# gcp-managed-cert.yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: gcp-managed-certificate
spec:
  domains:
    - FQDN_1
    - FQDN_2
```

`FQDN_1`, `FQDN_2`: Fully-qualified domain names that you own. For example, example.com.

Apply the configuration:

```bash
kubectl apply -f gcp-managed-cert.yaml
```

#### Update the Ingress resource

> **Note:** Replace `{APP_NAME}` with your application name.

If you have tls section in your Ingress resource, remove it.

```bash
kubectl edit ingress ${APP_NAME}-gateway-ingress
```

Update the Ingress resource to reference the `ManagedCertificate` resource:

```bash
kubectl annotate ingress ${APP_NAME}-gateway-ingress networking.gke.io/manage-certificates=gcp-managed-certificate
```

## Check the status of the certificate

### Using kubectl

To check the status of the certificate, run the following command:

```bash
kubectl describe managedcertificate
```

In the output, look for the `Status`. The status contains `Certificate Status`.
`Certificate Name` is the GCP managed certificate name.

### Using the Google Cloud CLI

To check all GCP managed certificates, run the following command:

```bash
gcloud compute ssl-certificates list --global
```

You need to find the certificate by the Google generated name and check the `MANAGED_STATUS` column.

You can get Google generated name from the `Certificate Name` [using kubectl](#using-kubectl).

## Disable HTTP Load Balancing

If you want to disable HTTP Load Balancing, you can do it after the certificate
is attached to the Ingress resource:

```bash
kubectl annotate ingress ${APP_NAME}-gateway-ingress kubernetes.io/ingress.allow-http: "false"
```

## Clean up

To delete the `ManagedCertificate` resource:

```bash
kubectl delete managedcertificate gcp-managed-certificate
```

Remove the `ManagedCertificate` reference from the Ingress resource:

```bash
kubectl annotate ingress managed-cert-ingress networking.gke.io/gcp-managed-certificate-
```

Also, check that the certificate is removed from the Google Cloud Console

```bash
gcloud compute ssl-certificates list --global
```

If the certificate is still present, delete it:

```bash
gcloud compute ssl-certificates delete ${CERTIFICATE_NAME} --global
```
