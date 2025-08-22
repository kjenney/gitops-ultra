"""
GitOps Infrastructure with Pulumi using Terraform modules for AWS S3, SQS, and Kubernetes integration.
"""

import json
import pulumi
import pulumi_aws as aws
import pulumi_kubernetes as k8s
from pulumi_terraform import RemoteStateReference

# Get configuration
config = pulumi.Config()
aws_config = pulumi.Config("aws")
project_config = pulumi.Config("project")
k8s_config = pulumi.Config("kubernetes")

region = aws_config.require("region")
prefix = project_config.require("prefix")
namespace = k8s_config.require("namespace")

# Create S3 bucket using Terraform module
s3_module = RemoteStateReference(
    "s3-bucket",
    backend_type="local",
    path="../terraform-modules/s3-bucket",
    args={
        "bucket_name": f"{prefix}-data-bucket",
        "versioning_enabled": True,
        "tags": {
            "Environment": pulumi.get_stack(),
            "Project": prefix,
            "ManagedBy": "Pulumi"
        }
    }
)

# Create SQS queue using Terraform module
sqs_module = RemoteStateReference(
    "sqs-queue",
    backend_type="local",
    path="../terraform-modules/sqs-queue",
    args={
        "queue_name": f"{prefix}-processing-queue",
        "enable_dlq": True,
        "max_receive_count": 3,
        "tags": {
            "Environment": pulumi.get_stack(),
            "Project": prefix,
            "ManagedBy": "Pulumi"
        }
    }
)

# Get current AWS account ID and partition
current = aws.get_caller_identity()
partition = aws.get_partition()

# Get EKS cluster OIDC issuer URL (assumes EKS cluster exists)
# In practice, you'd either create the EKS cluster here or reference an existing one
cluster_name = f"{prefix}-cluster"
cluster = aws.eks.get_cluster(name=cluster_name)

def create_assume_role_policy(cluster_data):
    """Create the assume role policy for IRSA"""
    oidc_url = cluster_data.identities[0].oidcs[0].issuer
    oidc_arn = f"arn:{partition.partition}:iam::{current.account_id}:oidc-provider/{oidc_url.replace('https://', '')}"
    
    return json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": oidc_arn
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        f"{oidc_url.replace('https://', '')}:sub": f"system:serviceaccount:{namespace}:{prefix}-service-account",
                        f"{oidc_url.replace('https://', '')}:aud": "sts.amazonaws.com"
                    }
                }
            }
        ]
    })

# Create IAM role for Kubernetes ServiceAccount
service_account_role = aws.iam.Role(
    "service-account-role",
    name=f"{prefix}-k8s-service-role",
    assume_role_policy=cluster.apply(create_assume_role_policy),
    tags={
        "Environment": pulumi.get_stack(),
        "Project": prefix,
        "ManagedBy": "Pulumi"
    }
)

# Attach S3 policy to service account role
s3_policy_attachment = aws.iam.RolePolicyAttachment(
    "s3-policy-attachment",
    role=service_account_role.name,
    policy_arn=s3_module.outputs["access_policy_arn"]
)

# Attach SQS policy to service account role
sqs_policy_attachment = aws.iam.RolePolicyAttachment(
    "sqs-policy-attachment",
    role=service_account_role.name,
    policy_arn=sqs_module.outputs["access_policy_arn"]
)

# Create Kubernetes namespace
k8s_namespace = k8s.core.v1.Namespace(
    "app-namespace",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name=namespace,
        labels={
            "name": namespace,
            "app.kubernetes.io/managed-by": "Pulumi"
        }
    )
)

# Create Kubernetes ServiceAccount with IAM role annotation
service_account = k8s.core.v1.ServiceAccount(
    "service-account",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name=f"{prefix}-service-account",
        namespace=namespace,
        annotations={
            "eks.amazonaws.com/role-arn": service_account_role.arn
        },
        labels={
            "app.kubernetes.io/name": f"{prefix}-service-account",
            "app.kubernetes.io/managed-by": "Pulumi"
        }
    ),
    opts=pulumi.ResourceOptions(depends_on=[k8s_namespace])
)

# Create ConfigMap with AWS resource information
config_map = k8s.core.v1.ConfigMap(
    "aws-resources-config",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name=f"{prefix}-aws-resources",
        namespace=namespace,
        labels={
            "app.kubernetes.io/name": f"{prefix}-config",
            "app.kubernetes.io/managed-by": "Pulumi"
        }
    ),
    data={
        "S3_BUCKET_NAME": s3_module.outputs["bucket_name"],
        "SQS_QUEUE_URL": sqs_module.outputs["queue_url"],
        "SQS_QUEUE_NAME": sqs_module.outputs["queue_name"],
        "AWS_REGION": region
    },
    opts=pulumi.ResourceOptions(depends_on=[k8s_namespace])
)

# Export outputs
pulumi.export("bucket_name", s3_module.outputs["bucket_name"])
pulumi.export("bucket_arn", s3_module.outputs["bucket_arn"])
pulumi.export("queue_url", sqs_module.outputs["queue_url"])
pulumi.export("queue_arn", sqs_module.outputs["queue_arn"])
pulumi.export("service_account_role_arn", service_account_role.arn)
pulumi.export("kubernetes_namespace", namespace)
pulumi.export("kubernetes_service_account_name", service_account.metadata.name)
