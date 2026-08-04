# AWS Load Balancer Integration with ReportPortal on EKS

This guide explains how to deploy ReportPortal on Amazon EKS using the AWS Application Load Balancer (ALB) managed by the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/).

## Table of Contents

- [Prerequisites](#prerequisites)
- [ALB Configuration](#alb-configuration)
  - [How ALB Works on EKS](#how-alb-works-on-eks)
  - [Deployment Steps](#alb-deployment-steps)
  - [Configuration Examples](#alb-configuration-examples)
  - [Troubleshooting](#alb-troubleshooting)
- [Best Practices](#best-practices)
- [Additional Resources](#additional-resources)

---

## Prerequisites

### 1. AWS EKS Cluster

- Amazon EKS cluster (Kubernetes v1.20+)
- [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html) installed in the cluster
- IAM permissions that allow the controller to create and manage load balancers

> **Install the AWS Load Balancer Controller first.** Follow the [official Helm installation guide](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html) — do not skip this step.

### 2. Required AWS Resources

| Resource | Purpose |
|---|---|
| VPC with public/private subnets | Load balancer placement |
| Security groups | Control inbound/outbound traffic |
| ACM certificate | TLS termination (HTTPS) |
| Route 53 hosted zone | Custom domain (optional) |

### 3. Subnet Tagging

The AWS Load Balancer Controller discovers subnets automatically using tags. Make sure your subnets are tagged correctly:

| Subnet type | Required tag | Value |
|---|---|---|
| Public (internet-facing ALB) | `kubernetes.io/role/elb` | `1` |
| Private (internal ALB) | `kubernetes.io/role/internal-elb` | `1` |
| Both | `kubernetes.io/cluster/<cluster-name>` | `shared` or `owned` |

Missing subnet tags are the most common reason a load balancer fails to be created.

---

## ALB Configuration

### How ALB Works on EKS

```
Browser → ALB (Layer 7) → Kubernetes Ingress → Services → Pods
```

When you create a Kubernetes `Ingress` resource with `ingress.class: alb`, the AWS Load Balancer Controller:
1. Reads the `Ingress` spec and its annotations
2. Provisions an ALB in your AWS account
3. Creates listener rules that route traffic to the correct Kubernetes Services by URL path

ReportPortal's Helm chart creates this `Ingress` automatically when `ingress.class: alb` is set in your values file.

### ALB Service Routing

The ALB routes incoming requests by path to the following ReportPortal services:

| URL path | Service | Port |
|---|---|---|
| `/` | `service-index` | 8080 |
| `/ui` | `service-ui` | 8080 |
| `/uat` | `service-authorization` | 9999 |
| `/api` | `service-api` | 8585 |

### ALB Deployment Steps

#### Step 1: Create a Values File

Create `values-alb.yaml` with your ALB configuration:

```yaml
ingress:
  enable: true
  hosts:
    - "your-domain.com"        # Replace with your actual domain
  path: ""                     # Use "/reportportal" if deploying to a subpath
  class: alb                   # Must be "alb" — the default is "nginx"
  annotations:
    # --- Scheme ---
    # "internet-facing" creates a public ALB; use "internal" for private (VPC-only) access
    alb.ingress.kubernetes.io/scheme: "internet-facing"

    # --- Target type ---
    # "ip" routes directly to Pod IPs — recommended when using VPC CNI
    alb.ingress.kubernetes.io/target-type: "ip"

    # --- Listeners ---
    # Accept both HTTP (for the redirect below) and HTTPS
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'

    # Automatically redirect all HTTP traffic to HTTPS
    alb.ingress.kubernetes.io/ssl-redirect: "443"

    # --- TLS ---
    # ARN of your certificate in AWS Certificate Manager
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:region:account:certificate/certificate-id"

    # --- Load balancer grouping (optional) ---
    # Allows multiple Ingress resources to share a single ALB, reducing cost
    alb.ingress.kubernetes.io/group.name: "k8s-reportportal"
    alb.ingress.kubernetes.io/group.order: "1"

    # --- Health checks ---
    alb.ingress.kubernetes.io/healthcheck-port: "traffic-port"
    alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"

    # --- Networking (optional — auto-discovered when subnets are tagged correctly) ---
    alb.ingress.kubernetes.io/security-groups: "sg-xxxxxxxxx,sg-yyyyyyyyy"
    alb.ingress.kubernetes.io/subnets: "subnet-xxxxxxxxx,subnet-yyyyyyyyy"

    # --- Performance ---
    # Increase the idle timeout if you run long-running API requests
    alb.ingress.kubernetes.io/load-balancer-attributes: "idle_timeout.timeout_seconds=60"

    # --- Session stickiness (optional) ---
    # Pins a user's requests to the same pod for 24 hours via a cookie
    alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400"
```

#### Step 2: Deploy ReportPortal

```bash
# Add the Helm repository
helm repo add reportportal https://k8s.reportportal.io
helm repo update

# Deploy ReportPortal with ALB configuration
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --values values-alb.yaml
```

#### Step 3: Verify the Deployment

```bash
# Check that the Ingress resource was created and has an address
kubectl get ingress -n reportportal

# Verify the ALB was provisioned in AWS
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-reportportal`)]'

# Check that target groups are healthy
aws elbv2 describe-target-groups \
  --query 'TargetGroups[?contains(TargetGroupName, `k8s-reportportal`)]'
```

The `ADDRESS` field in `kubectl get ingress` shows the ALB DNS name once provisioning completes (usually 2–3 minutes).

#### Step 4: Configure DNS

Point your domain at the ALB using an **Alias** record in Route 53 (recommended) or a **CNAME**:

```bash
# Get the ALB DNS name
kubectl get ingress -n reportportal -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

In the AWS Console → Route 53 → your hosted zone, create:
- **Type**: `A` (Alias) pointing to the ALB DNS name, **or**
- **Type**: `CNAME` pointing to the ALB DNS name (not supported at the zone apex)

---

### ALB Configuration Examples

#### Example 1: Minimal Setup (HTTPS only)

The simplest configuration to get HTTPS working:

```yaml
ingress:
  enable: true
  hosts:
    - reportportal.example.com
  class: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

#### Example 2: Internal ALB with Custom Security Groups

For deployments accessible only within your VPC:

```yaml
ingress:
  enable: true
  hosts:
    - internal-reportportal.example.com
  class: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: "internal"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/security-groups: "sg-12345678,sg-87654321"
    alb.ingress.kubernetes.io/subnets: "subnet-12345678,subnet-87654321"
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

#### Example 3: ALB with Session Stickiness

Recommended when users experience intermittent session drops:

```yaml
ingress:
  enable: true
  hosts:
    - reportportal.example.com
  class: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400"
```

---

### ALB Troubleshooting

#### ALB was not created

```bash
# Look for errors in the AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Confirm the controller has the required IAM permissions
aws iam get-role-policy \
  --role-name aws-load-balancer-controller \
  --policy-name AWSLoadBalancerControllerIAMPolicy
```

Common causes:
- Missing IAM permissions on the controller's service account
- Subnets not tagged correctly (see [Subnet Tagging](#3-subnet-tagging))
- No available subnets found in the VPC

#### SSL certificate not working

```bash
# Confirm the certificate exists and is in "Issued" status
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:region:account:certificate/certificate-id"

# Find a certificate by domain name
aws acm list-certificates \
  --query 'CertificateSummaryList[?DomainName==`your-domain.com`]'
```

#### Pods not receiving traffic

```bash
# Inspect Ingress events for provisioning errors
kubectl describe ingress -n reportportal

# Check target health in the ALB target group
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check ALB listeners and routing rules
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>
```

---

## Best Practices

### Security

- Use `scheme: internal` for deployments not intended for public internet access
- Define explicit security groups rather than relying on auto-generated rules
- Enable [AWS WAF](https://aws.amazon.com/waf/) on ALB for additional Layer 7 threat protection
- Always enforce HTTPS — never expose ReportPortal over plain HTTP in production

### Monitoring

- Enable **access logs** on the ALB (stored in S3) via `load-balancer-attributes`
- Create **CloudWatch alarms** on:
  - `UnHealthyHostCount > 0` — target group health degraded
  - `HTTPCode_Target_5XX_Count` — backend errors
- Monitor target group health regularly: `aws elbv2 describe-target-health`

### High Availability

- Always specify subnets in **at least two Availability Zones**
- Use `healthy-threshold-count: 2` and `unhealthy-threshold-count: 2` for fast failover detection
- For ALB, use `group.name` + `group.order` when sharing a load balancer across multiple Ingress resources

### Cost

- ALB is billed per LCU (request rate, active connections, rule evaluations per hour)
- Use `alb.ingress.kubernetes.io/group.name` to share a single ALB across multiple Helm releases and reduce per-LB costs

---

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ALB Ingress Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [Install AWS Load Balancer Controller (Helm)](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
- [Route application and HTTP traffic with Application Load Balancers](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)
- [ReportPortal Documentation](https://reportportal.io/docs)
- [ReportPortal GitHub Issues](https://github.com/reportportal/kubernetes/issues)

---

## Support

For issues specific to ReportPortal ALB deployment:

- Check the [ReportPortal GitHub Issues](https://github.com/reportportal/kubernetes/issues)
- Review AWS Load Balancer Controller logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
- Consult AWS support for load balancer provisioning issues
