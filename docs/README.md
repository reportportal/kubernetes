# Kubernetes Installation Guides

This directory contains installation and configuration guides for ReportPortal on Kubernetes. The Helm chart is in [reportportal/](../reportportal); default values are in [reportportal/values.yaml](../reportportal/values.yaml).

## Ingress & Networking

- [AWS Application Load Balancer (ALB) Deployment Guide](alb-deployment-guide.md) — Deploy ReportPortal on EKS with ALB ingress, path-based routing, and TLS via ACM
- [Gateway API Deployment Guide](gateway-api-deployment-guide.md) — Modern Kubernetes Gateway API with HTTPRoute (replaces Ingress)
- [Cert-Manager Configuration](cert-manager-config.md) — Automated TLS certificate provisioning with Let's Encrypt
- [Certificates Management](certificates-management.md) — Managing TLS certificates for secure HTTPS connections
- [Google Managed Certificates Configuration](gcp-managed-cert-config.md) — GCP-managed SSL certificates for GKE deployments

## Storage Configuration

- [Filesystem Storage on a Single-Node Cluster](filesystem-one-node.md) — Use filesystem storage with local-path or hostPath on Rancher Desktop, Minikube, or one-node k3s
- [S3 and Filesystem Storage on EKS](s3-storage-eks.md) — Configure Amazon S3 (with IRSA) or shared filesystem (PVC) storage for EKS deployments

## Installation Guides

- [Install ReportPortal on GKE](gke-install.md) — Full installation guide for Google Kubernetes Engine
- [Install ReportPortal on Minikube](minikube-install.md) — Local development setup with Minikube
- [Helm Pre-upgrade Guide](helm-pre-upgrade.md) — Required steps before upgrading the Helm chart
- [Parameters Reference](parameters-reference.md) — Complete reference for all Helm chart values
- [Docker Hardened Images (DHI) Usage](dhi-usage.md) — Configure PostgreSQL and RabbitMQ with Docker Hardened Images
- [Audit Logs and Log Collection](audit-logs.md) — Enable audit logging and ship logs to external backends

## Google Kubernetes Engine (GKE) Application

Repository wrapper for Google Cloud Platform Marketplace:
[reportportal/gcp-k8s-app](https://github.com/reportportal/gcp-k8s-app)

## Feedback

You can provide feedback on these installation guides by
[opening an issue](https://github.com/reportportal/kubernetes/issues/new/choose).
