"""
GitOps Infrastructure with Pulumi - Pure Python Implementation
Creates AWS S3, SQS, IAM resources and Kubernetes integration using native Pulumi resources.
"""

import json
import pulumi
import pulumi_aws as aws
import pulumi_kubernetes as k8s

# Get configuration
config = pulumi.Config()
aws_config = pulumi.Config("aws")
project_config = pulumi.Config("project")
k8s_config = pulumi.Config("kubernetes")

region = aws_config.require("region")
prefix = project_config.require("prefix")
namespace = k8s_config.require("namespace")

# Tags to apply to all resources
common_tags = {
    "Environment": pulumi.get_stack(),
    "Project": prefix,
    "ManagedBy": "Pulumi",
    "GitOps": "true"
}

# ============================================================================
# S3 Bucket Resources (equivalent to terraform s3-bucket module)
# ============================================================================

bucket_name = f"{prefix}-data-bucket"

# Create S3 bucket
s3_bucket = aws.s3.Bucket(
    "data-bucket",
    bucket=bucket_name,
    tags=common_tags
)

# Configure S3 bucket versioning
s3_versioning = aws.s3.BucketVersioningV2(
    "bucket-versioning",
    bucket=s3_bucket.id,
    versioning_configuration=aws.s3.BucketVersioningV2VersioningConfigurationArgs(
        status="Enabled"
    )
)

# Configure S3 bucket encryption
s3_encryption = aws.s3.BucketServerSideEncryptionConfigurationV2(
    "bucket-encryption",
    bucket=s3_bucket.id,
    rules=[aws.s3.BucketServerSideEncryptionConfigurationV2RuleArgs(
        apply_server_side_encryption_by_default=aws.s3.BucketServerSideEncryptionConfigurationV2RuleApplyServerSideEncryptionByDefaultArgs(
            sse_algorithm="AES256"
        )
    )]
)

# Block public access to S3 bucket
s3_public_access_block = aws.s3.BucketPublicAccessBlock(
    "bucket-public-access-block",
    bucket=s3_bucket.id,
    block_public_acls=True,
    block_public_policy=True,
    ignore_public_acls=True,
    restrict_public_buckets=True
)

# IAM policy for S3 access
s3_access_policy = aws.iam.Policy(
    "s3-access-policy",
    name=f"{bucket_name}-access-policy",
    description=f"Policy for accessing S3 bucket {bucket_name}",
    policy=s3_bucket.arn.apply(lambda arn: json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [arn, f"{arn}/*"]
            }
        ]
    })),
    tags=common_tags
)

# ============================================================================
# SQS Queue Resources (equivalent to terraform sqs-queue module)
# ============================================================================

queue_name = f"{prefix}-processing-queue"

# Create dead letter queue
dlq = aws.sqs.Queue(
    "dead-letter-queue",
    name=f"{queue_name}-dlq",
    tags=common_tags
)

# Create main SQS queue with dead letter queue configuration
sqs_queue = aws.sqs.Queue(
    "processing-queue",
    name=queue_name,
    delay_seconds=0,
    max_message_size=262144,
    message_retention_seconds=345600,
    visibility_timeout_seconds=30,
    receive_wait_time_seconds=0,
    redrive_policy=dlq.arn.apply(lambda dlq_arn: json.dumps({
        "deadLetterTargetArn": dlq_arn,
        "maxReceiveCount": 3
    })),
    tags=common_tags
)

# IAM policy for SQS access
sqs_access_policy = aws.iam.Policy(
    "sqs-access-policy",
    name=f"{queue_name}-access-policy",
    description=f"Policy for accessing SQS queue {queue_name}",
    policy=pulumi.Output.all(sqs_queue.arn, dlq.arn).apply(lambda arns: json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "sqs:SendMessage",
                    "sqs:ReceiveMessage",
                    "sqs:DeleteMessage",
                    "sqs:GetQueueAttributes",
                    "sqs:GetQueueUrl"
                ],
                "Resource": arns
            }
        ]
    })),
    tags=common_tags
)

# ============================================================================
# IRSA (IAM Roles for Service Accounts) Configuration
# ============================================================================

# Get current AWS account ID and partition
current = aws.get_caller_identity()
partition = aws.get_partition()

# Get EKS cluster OIDC issuer URL (assumes EKS cluster exists)
cluster_name = f"{prefix}-cluster"

# Try to get cluster info, but handle case where cluster doesn't exist yet
try:
    cluster = aws.eks.get_cluster(name=cluster_name)
    cluster_exists = True
except:
    cluster_exists = False
    pulumi.log.warn(f"EKS cluster '{cluster_name}' not found. IRSA will be configured but may not work until cluster exists.")

def create_assume_role_policy_basic():
    """Create a basic assume role policy that works without EKS cluster"""
    return json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": f"arn:{partition.partition}:iam::{current.account_id}:root"
                },
                "Action": "sts:AssumeRole",
                "Condition": {
                    "StringEquals": {
                        "sts:ExternalId": f"{prefix}-external-id"
                    }
                }
            }
        ]
    })

def create_assume_role_policy_irsa(cluster_data):
    """Create the assume role policy for IRSA when cluster exists"""
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
if cluster_exists:
    assume_role_policy = cluster.apply(create_assume_role_policy_irsa)
else:
    assume_role_policy = create_assume_role_policy_basic()

service_account_role = aws.iam.Role(
    "service-account-role",
    name=f"{prefix}-k8s-service-role",
    assume_role_policy=assume_role_policy,
    tags=common_tags
)

# Attach S3 policy to service account role
s3_policy_attachment = aws.iam.RolePolicyAttachment(
    "s3-policy-attachment",
    role=service_account_role.name,
    policy_arn=s3_access_policy.arn
)

# Attach SQS policy to service account role
sqs_policy_attachment = aws.iam.RolePolicyAttachment(
    "sqs-policy-attachment",
    role=service_account_role.name,
    policy_arn=sqs_access_policy.arn
)

# ============================================================================
# Kubernetes Resources
# ============================================================================

# Create Kubernetes namespace
k8s_namespace = k8s.core.v1.Namespace(
    "app-namespace",
    metadata=k8s.meta.v1.ObjectMetaArgs(
        name=namespace,
        labels={
            "name": namespace,
            "app.kubernetes.io/managed-by": "Pulumi",
            "gitops.io/environment": pulumi.get_stack()
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
            "app.kubernetes.io/managed-by": "Pulumi",
            "gitops.io/environment": pulumi.get_stack()
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
            "app.kubernetes.io/managed-by": "Pulumi",
            "gitops.io/environment": pulumi.get_stack()
        }
    ),
    data={
        "S3_BUCKET_NAME": s3_bucket.bucket,
        "SQS_QUEUE_URL": sqs_queue.url,
        "SQS_QUEUE_NAME": sqs_queue.name,
        "SQS_DLQ_URL": dlq.url,
        "AWS_REGION": region,
        "AWS_DEFAULT_REGION": region
    },
    opts=pulumi.ResourceOptions(depends_on=[k8s_namespace])
)

# ============================================================================
# Outputs
# ============================================================================

# Export all important outputs
pulumi.export("bucket_name", s3_bucket.bucket)
pulumi.export("bucket_arn", s3_bucket.arn)
pulumi.export("bucket_domain_name", s3_bucket.bucket_domain_name)
pulumi.export("queue_url", sqs_queue.url)
pulumi.export("queue_arn", sqs_queue.arn)
pulumi.export("queue_name", sqs_queue.name)
pulumi.export("dlq_url", dlq.url)
pulumi.export("dlq_arn", dlq.arn)
pulumi.export("service_account_role_arn", service_account_role.arn)
pulumi.export("service_account_role_name", service_account_role.name)
pulumi.export("kubernetes_namespace", namespace)
pulumi.export("kubernetes_service_account_name", service_account.metadata.name)
pulumi.export("s3_access_policy_arn", s3_access_policy.arn)
pulumi.export("sqs_access_policy_arn", sqs_access_policy.arn)

# Export configuration for debugging
pulumi.export("config", {
    "region": region,
    "prefix": prefix,
    "namespace": namespace,
    "stack": pulumi.get_stack()
})
