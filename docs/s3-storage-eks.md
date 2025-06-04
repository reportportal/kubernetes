# S3-Based Storage Using IAM Role for Amazon EKS-based ReportPortal

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
- [EKS-based Installation](#3-eks-based-installation)


## Requirements
1. S3 Bucket
2. AWS IAM roles granting S3 read/write permissions.
3. Kubernetes-based installation:
    - EKS cluster version ≥ 1.28.
    - OIDC provider enabled for the cluster. [How to create an IAM OIDC provider for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).


## 1. S3 Bucket

Create an Amazon S3 bucket to store your data. Replace `my-rp-bucket` with a unique bucket name and specify the desired AWS region.

```bash
aws s3api create-bucket --bucket my-rp-bucket --region us-east-1
```

> To create a bucket outside of the `us-east-1` region, add the following flag: `--create-bucket-configuration LocationConstraint=<region>`, replacing `<region>` with your desired AWS region.

Ensure that the bucket name adheres to [Amazon S3 bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html).

## 2. AWS IAM Role

To enable secure access to your S3 bucket, you need to create an AWS IAM role with the appropriate trust and permissions policies.

### Step 1: Define the Trust Policy

The trust policy specifies which AWS service or entity is allowed to assume the role. Save the following JSON content to a file named `trust-policy.json`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com",
                    "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:NAMESPACE:reportportal"
                }
            }
        }
    ]
}
```

Replace the placeholders with the appropriate values:
- `ACCOUNT_ID`: Your AWS account ID.
- `REGION`: The AWS region where your EKS cluster is deployed.
- `OIDC_ID`: The unique identifier of your OIDC provider. [How to create an IAM OIDC provider for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)
- `NAMESPACE`: The Kubernetes namespace of the service account.
- `reportportal`: The name of the Kubernetes service account.

This trust policy ensures that only the specified Kubernetes service account can assume the IAM role via the OIDC provider.

### Step 2: Create the IAM Role

Use the AWS CLI to create the IAM role with  the trust policy:

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
            "Sid": "AllowListAndLocation",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::my-rp-bucket"
        },
        {
            "Sid": "AllowObjectOpsAnywhere",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:GetObjectAcl",
                "s3:GetObjectVersion"
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

## 3. Kubernetes-based Installation

To grant a Kubernetes pod on EKS read/write access to S3, use IAM Roles for Service Accounts (IRSA). This approach issues temporary credentials by having the pod assume an IAM role via OIDC

Update the `values.yaml` file with the appropriate storage configuration:

```yaml
# Activate Service Account for the ReportPortal application
global:
  serviceAccount:
    create: true
    name: reportportal
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/my-rp-s3-role"


storage:
  # Ref.: https://reportportal.io/docs/installation-steps-advanced/file-storage-options/S3CloudStorage
  type: s3
  # Leave `accesskey` and `secretkey` empty for IAM role-based access
  accesskey:
  secretkey:
  # Specify the AWS region. Ref.: https://jclouds.apache.org/reference/javadoc/2.6.x/org/jclouds/aws/domain/Region.html
  region: "us-standard" # JCloud ref. to `us-east-1`
  bucket:
    type: single
    bucketDefaultName: "my-rp-bucket" # Bucket created from step 1

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
