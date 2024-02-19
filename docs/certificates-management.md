# Use certificates for secure HTTPS connections

Certificates are used to secure connections between clients and servers over HTTPS.
We provide built-in certificate managers to automatically provision, renew,
and manage certificates for your domain.

You must own a domain and opportunity to manage DNS records to use certificates.

There are two options for managing certificates:

- [Google-managed SSL certificates](./gcp-managed-cert-config.md)
are available only for use with Google Cloud Platform (GCP) services.
- [Cert-Manager](./cert-manager-config.md)
is vendor-agnostic and can be used with any Kubernetes cluster and Cloud providers.
