# Amazon S3 Access Using IAM Role

This document outlines the requirements and configuration steps to enable read/write access to Amazon S3 using the AWS SDK for Java ([software.amazon.awssdk:aws-core:2.31.23](https://sdk.amazonaws.com/java/api/latest/software/amazon/awssdk/auth/credentials/DefaultCredentialsProvider.html)) in two deployment scenarios:

1. Kubernetes on EKS (IAM Roles for Service Accounts)
2. Docker on an EC2 instance (Instance Profile)

## Table of Contents

- [Requirements](#requirements)
- [S3 Bucket](#1-s3-bucket)
- [AWS IAM Role](#2-aws-iam-role)
  - [Step 1: Define the Trust Policy](#step-1-define-the-trust-policy)
  - [Step 2: Create the IAM Role](#step-2-create-the-iam-role)
  - [Step 3: Define the Permissions Policy](#step-3-define-the-permissions-policy)
  - [Step 4: Attach the Permissions Policy](#step-4-attach-the-permissions-policy)
- [Kubernetes-based Installation](#2-kubernetes-based-installation)
- [Docker-based Installation](#3-docker-based-installation)


## Requirements
1. S3 Bucket
2. AWS IAM roles granting S3 read/write permissions.
3. Kubernetes-based installation:
    - EKS cluster version ≥ 1.28.
    - OIDC provider enabled for the cluster. [How to create an IAM OIDC provider for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).
4. Docker-based installation:
    - EC2 instance with Docker and Docker Compose installed.
    - IAM instance profile attached with S3 read/write permissions.

## 1. S3 Bucket

Create an Amazon S3 bucket to store your data. Replace `my-rp-bucket` with a unique bucket name and specify the desired AWS region.

```bash
aws s3api create-bucket --bucket my-rp-bucket --region us-east-1
```

Ensure that the bucket name adheres to [Amazon S3 bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html).

## 2. AWS IAM Role

To enable secure access to your S3 bucket, you need to create an AWS IAM role with the appropriate trust and permissions policies.

### Step 1: Define the Trust Policy

The trust policy determines which AWS service or entity can assume the role. Save the following JSON content to a file named `trust-policy.json`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "s3.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

### Step 2: Create the IAM Role

Use the AWS CLI to create the IAM role with the trust policy:

```bash
aws iam create-role --role-name my-rp-s3-role \
    --assume-role-policy-document file://trust-policy.json
```

### Step 3: Define the Permissions Policy

The permissions policy specifies the actions the IAM role can perform on the S3 bucket. Save the following JSON content to a file named `s3-rw-policy.json`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::my-rp-bucket"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::my-rp-bucket/*"
        }
    ]
}
```

### Step 4: Attach the Permissions Policy

Attach the permissions policy to the IAM role using the AWS CLI:

```bash
aws iam put-role-policy --role-name my-rp-s3-role \
    --policy-name S3AccessPolicy \
    --policy-document file://s3-rw-policy.json
```

By completing these steps, the IAM role will have the necessary permissions to interact with the specified S3 bucket securely.

## 2. Kubernetes-based Installation

To grant a Kubernetes pod on EKS read/write access to S3, use IAM Roles for Service Accounts (IRSA). This approach issues temporary credentials by having the pod assume an IAM role via OIDC

Update the `values.yaml` file with the appropriate storage configuration:

```yaml
# Activate Service Account for the ReportPortal application
global:
  serviceAccount:
    create: true
    name: reportportal
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::my-account-id:role/my-rp-s3-role"


storage:
  # Ref.: https://reportportal.io/docs/installation-steps-advanced/FileStorageOptions
  type: s3
  # Leave `accesskey` and `secretkey` empty for IAM role-based access
  accesskey:
  secretkey:
  # Specify the AWS region. Ref.: https://jclouds.apache.org/reference/javadoc/2.6.x/org/jclouds/aws/domain/Region.html
  region: "us-standard" # JCloud ref. to `us-east-1`
  bucket:
    type: single
    bucketDefaultName: "my-rp-bucket"

# Disable the MinIO dependency
minio:
  enable: false
```

Install ReportPortal using Helm:

```bash
helm install my-release \
  --set uat.superadminInitPasswd.password="MyPassword" \
  -f values.yaml \
  reportportal/reportportal
```

This configuration ensures that ReportPortal uses Amazon S3 for storage with IAM role-based access, while disabling the default MinIO dependency.

## 3. Docker-based installation

When running ReportPortal in Docker containers on an EC2 instance with an attached IAM instance profile, the AWS SDK will automatically retrieve credentials from the EC2 Instance Metadata Service (IMDS) without any additional configuration.

All you need to do is attach the role created in the first step to the EC2 instance as an instance profile, or modify an existing one to include S3 read/write permissions.

How to [Attach an IAM role to an instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/attach-iam-role.html)