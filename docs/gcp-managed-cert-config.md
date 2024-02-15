# Use Google-managed SSL certificates

You can use Google-managed SSL certificates to secure your custom domain with HTTPS.
Google-managed SSL certificates are provisioned, renewed, and managed for your domain by Google.
You can use Google-managed SSL certificates with Google Kubernetes Engine (GKE) and Google Cloud Load Balancing.

Comprehensive documentation is available at [Google-managed SSL certificates](https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs).

## Limitations

* Don't support wildcard domains.
* The domain name must be no longer than 63 characters.
* Your ingressClassName must be "gce".
* You must apply Ingress and ManagedCertificate resources in the same project and namespace.

## Before you begin

## Setting up a Google-managed certificate

```yaml
# gcp-managed-cert.yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: gcp-managed-cert
spec:
  domains:
    - FQDN_1
    - FQDN_2
```

`FQDN_1`, `FQDN_2`: Fully-qualified domain names that you own. For example, example.com.

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    networking.gke.io/managed-certificates: gcp-managed-cert
  name: {APP_NAME}-gateway-ingress
spec:
  rules:
  - http:
      paths:
      - backend:
          service:
            name: {APP_NAME}-index
            port:
              name: headless
        path: /
        pathType: Prefix
      - backend:
          service:
            name: {APP_NAME}-ui
            port:
              name: headless
        path: /ui
        pathType: Prefix
      - backend:
          service:
            name: {APP_NAME}-uat
            port:
              name: headless
        path: /uat
        pathType: Prefix
      - backend:
          service:
            name: {APP_NAME}-api
            port:
              name: headless
        path: /api
        pathType: Prefix
```
