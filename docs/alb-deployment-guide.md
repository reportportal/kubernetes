# AWS Application Load Balancer (ALB) Deployment Guide for ReportPortal

This guide provides comprehensive instructions for deploying ReportPortal on AWS EKS using the AWS Application Load Balancer (ALB) Ingress Controller.

## Table of Contents

- [Prerequisites](#prerequisites)
- [ALB Configuration Overview](#alb-configuration-overview)
- [Deployment Steps](#deployment-steps)
- [Configuration Examples](#configuration-examples)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Prerequisites

### 1. AWS EKS Cluster
- EKS cluster running Kubernetes 1.19+
- AWS Load Balancer Controller installed
- Proper IAM permissions for ALB creation

### 2. Required AWS Resources
- VPC with public/private subnets
- Security groups allowing HTTP/HTTPS traffic
- SSL/TLS certificate in AWS Certificate Manager (ACM)
- Route 53 hosted zone (optional, for custom domains)

### 3. AWS Load Balancer Controller Installation

The AWS Load Balancer Controller must be installed in your EKS cluster before deploying ReportPortal with ALB.

**Recommended Installation Method:**
- **Helm (Recommended)**: [Install AWS Load Balancer Controller using Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)

> **Note**: Follow the official AWS documentation for the most up-to-date installation instructions, as installation methods and requirements may change over time.

## ALB Configuration Overview

**Important**: By default, ReportPortal uses `nginx` as the ingress class. To use ALB, you must manually change the ingress class in your values.yaml file from `nginx` to `alb`.

ReportPortal's ALB integration includes:

### 1. Ingress Configuration
- **Class**: `alb` (must be manually set in values.yaml, defaults to `nginx`)
- **TLS**: Handled via AWS Certificate Manager (ACM) ARN
- **Path-based routing**: Routes traffic to different services based on URL paths

### 2. Service Routing
The ALB routes traffic to the following services:
- `/` → `service-index` (port 8080)
- `/ui` → `service-ui` (port 8080) 
- `/uat` → `service-authorization` (port 9999)
- `/api` → `service-api` (port 8585)

### 3. Health Checks
Each service has individual health check configurations:
- **Index Service**: `/{path}/health`
- **UI Service**: `/{path}/ui/health`
- **UAT Service**: `/{path}/uat/health`
- **API Service**: `/{path}/api/health`

## Deployment Steps

### 1. Create Values File

Create a `values-alb.yaml` file with ALB-specific configuration. **Important**: Change the ingress class from the default `nginx` to `alb`:

```yaml
# ALB Ingress Configuration
ingress:
  enable: true
  hosts:
    - "your-domain.com"  # Replace with your domain
  path: ""  # Set to "/reportportal" if deploying to subpath
  class: alb  # Changed from default 'nginx' to 'alb'
  annotations:
    alb:
      # Basic ALB configuration
      alb.ingress.kubernetes.io/scheme: "internet-facing"  # or "internal"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      
      # Load balancer grouping (optional)
      alb.ingress.kubernetes.io/group.name: "k8s-reportportal"
      alb.ingress.kubernetes.io/group.order: "1"
      
      # Health check settings
      alb.ingress.kubernetes.io/healthcheck-port: "traffic-port"
      alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
      alb.ingress.kubernetes.io/success-codes: "200"
      alb.ingress.kubernetes.io/healthy-threshold-count: "2"
      alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
      
      # Security settings
      alb.ingress.kubernetes.io/security-groups: "sg-xxxxxxxxx,sg-yyyyyyyyy"
      alb.ingress.kubernetes.io/subnets: "subnet-xxxxxxxxx,subnet-yyyyyyyyy"
      
      # SSL/TLS settings
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:region:account:certificate/certificate-id"
      
      # Additional ALB attributes
      alb.ingress.kubernetes.io/load-balancer-attributes: "idle_timeout.timeout_seconds=60"
      alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400"
```

### 2. Deploy ReportPortal

```bash
# Add the Helm repository
helm repo add reportportal https://reportportal.github.io/kubernetes
helm repo update

# Deploy ReportPortal with ALB configuration
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --values values-alb.yaml
```

### 3. Verify Deployment

```bash
# Check ingress status
kubectl get ingress -n reportportal

# Check ALB creation
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-reportportal`)]'

# Check target groups
aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName, `k8s-reportportal`)]'
```

## Configuration Examples

### Example 1: Basic ALB Configuration

```yaml
ingress:
  enable: true
  hosts: 
    - reportportal.example.com
  class: alb
  annotations:
    alb:
      alb.ingress.kubernetes.io/scheme: "internet-facing"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### Example 2: Internal ALB with Custom Security Groups

```yaml
ingress:
  enable: true
  hosts: 
   - internal-reportportal.example.com
  class: alb
  annotations:
    alb:
      alb.ingress.kubernetes.io/scheme: "internal"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/security-groups: "sg-12345678,sg-87654321"
      alb.ingress.kubernetes.io/subnets: "subnet-12345678,subnet-87654321"
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### Example 3: ALB with Session Stickiness

```yaml
ingress:
  enable: true
  hosts: 
    - reportportal.example.com
  class: alb
  annotations:
    alb:
      alb.ingress.kubernetes.io/scheme: "internet-facing"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400"
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

## Troubleshooting

### Common Issues

#### 1. ALB Not Created
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM permissions
aws iam get-role-policy --role-name aws-load-balancer-controller --policy-name AWSLoadBalancerControllerIAMPolicy
```

#### 2. SSL Certificate Issues
```bash
# Verify certificate ARN
aws acm describe-certificate --certificate-arn "arn:aws:acm:region:account:certificate/certificate-id"

# Check certificate status
aws acm list-certificates --query 'CertificateSummaryList[?DomainName==`your-domain.com`]'
```

### Debugging Commands

```bash
# Check ingress events
kubectl describe ingress -n reportportal

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check ALB listeners
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>
```

## Best Practices

### 1. Security
- Use internal ALB for private access
- Implement proper security groups
- Use AWS WAF for additional protection
- Enable access logs for monitoring

### 2. Monitoring
- Enable ALB access logs
- Set up CloudWatch alarms
- Monitor target group health
- Track response times and error rates

### 3. High Availability
- Deploy across multiple AZs
- Use multiple subnets
- Implement proper health checks

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ReportPortal Documentation](https://reportportal.io/docs)
- [Route application and HTTP traffic with Application Load Balancers](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

## Support

For issues specific to ReportPortal ALB deployment:
- Check the [ReportPortal GitHub Issues](https://github.com/reportportal/kubernetes/issues)
- Review AWS Load Balancer Controller logs
- Consult AWS support for ALB-specific issues
