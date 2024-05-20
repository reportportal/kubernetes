# Using Cert-Manager to manage certificates

- [Using Cert-Manager to manage certificates](#using-cert-manager-to-manage-certificates)
  - [Overview](#overview)
  - [Install Cert-Manager](#install-cert-manager)
  - [Create an Issuer resource](#create-an-issuer-resource)
  - [Configure the Ingress resource](#configure-the-ingress-resource)

## Overview

You can use [Cert-Manager](https://cert-manager.io/docs/) to manage certificates for your domain name.

Detailed instructions on how to install and configure Cert-Manager can be found in the [official documentation](https://cert-manager.io/docs/getting-started/).

## Install Cert-Manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.yaml
```

This will install the latest version of Cert-Manager.

Check the installation:

```bash
kubectl -n cert-manager get all
```

## Create an Issuer resource

Create a file called `letsencrypt.yaml` with the following content:

```yaml
# letsencrypt.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: {EMAIL_ADDRESS} # Replace this with your email address
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          name: {APP_NAME}-gateway-ingress
```

Apply the configuration:

```bash
kubectl apply -f letsencrypt.yaml
```

## Configure the Ingress resource

Open the Ingress resource for editing:

```bash
kubectl edit ingress {APP_NAME}-gateway-ingress
```

Add the following annotations:

```yaml
...
metadata:
  annotations:
    cert-manager.io/issuer: letsencrypt
...
```

Add the following tls section if it does not exist:

```yaml
spec:
  tls:
  - secretName: {APP_NAME}-gateway-tls
    hosts:
      - example.com
...
```

After saving the changes, Cert-Manager will automatically request a certificate from Let's Encrypt
and store it in the `APP_NAME-gateway-tls` secret.

Read more about Cert-Manager and Let's Encrypt integration in
the [official documentation](https://cert-manager.io/docs/configuration/acme/).
