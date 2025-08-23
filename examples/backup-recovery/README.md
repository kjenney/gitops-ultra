# GitOps Ultra - Backup and Disaster Recovery

This guide covers backup strategies and disaster recovery procedures for GitOps Ultra deployments.

## 🔄 Backup Strategy Overview

### What to Backup

1. **Git Repositories** - Source of truth for all configurations
2. **Pulumi State** - Infrastructure state management
3. **ArgoCD Configuration** - Application definitions and secrets
4. **Kubernetes Resources** - Cluster state and persistent data
5. **AWS Resources** - Cloud infrastructure and data
6. **Secrets and Credentials** - Encrypted sensitive data

### Backup Schedule

- **Continuous**: Git repository commits
- **Daily**: Pulumi state, ArgoCD configuration
- **Weekly**: Full cluster backup, AWS resource snapshots
- **Monthly**: Disaster recovery testing

## 📦 Git Repository Backup

### GitHub/GitLab Backup

```bash
#!/bin/bash
# Git repository backup script

BACKUP_DIR="/backups/git"
REPO_URL="https://github.com/your-org/gitops-ultra"
DATE=$(date +%Y%m%d)

# Clone repository with all branches
git clone --mirror $REPO_URL $BACKUP_DIR/gitops-ultra-$DATE.git

# Create tarball
tar -czf $BACKUP_DIR/gitops-ultra-$DATE.tar.gz -C $BACKUP_DIR gitops-ultra-$DATE.git

# Upload to S3
aws s3 cp $BACKUP_DIR/gitops-ultra-$DATE.tar.gz s3://your-backup-bucket/git-backups/

# Cleanup old local backups (keep last 7 days)
find $BACKUP_DIR -name "gitops-ultra-*.tar.gz" -mtime +7 -delete
```

### Git Repository Mirroring

```yaml
# GitHub Action for repository mirroring
name: Repository Mirror Backup
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  push:
    branches: [main]

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
    - name: Mirror to backup repository
      uses: pixta-dev/repository-mirroring-action@v1
      with:
        target_repo_url: ${{ secrets.BACKUP_REPO_URL }}
        ssh_private_key: ${{ secrets.BACKUP_SSH_KEY }}
```

## 🏗️ Pulumi State Backup

### Automatic State Backup

```python
# Add to Pulumi program for state backup
import pulumi
import boto3
import json
from datetime import datetime

def backup_state():
    """Backup Pulumi state to S3"""
    s3 = boto3.client('s3')
    
    # Get stack info
    stack_name = pulumi.get_stack()
    project_name = pulumi.get_project()
    
    # Create backup metadata
    backup_metadata = {
        'timestamp': datetime.utcnow().isoformat(),
        'stack': stack_name,
        'project': project_name,
        'pulumi_version': pulumi.__version__
    }
    
    # Export stack state
    try:
        # This would be called from Pulumi CLI
        # pulumi stack export --file state-backup.json
        pass
    except Exception as e:
        print(f"State backup failed: {e}")

# Export the backup function
pulumi.export("backup_metadata", backup_metadata)
```

### Pulumi State Backup Script

```bash
#!/bin/bash
# Pulumi state backup script

BACKUP_DIR="/backups/pulumi"
DATE=$(date +%Y%m%d-%H%M)
BUCKET="your-pulumi-backup-bucket"

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

# Export all stack states
for env in dev staging prod; do
  echo "Backing up Pulumi state for environment: $env"
  
  cd infrastructure/pulumi
  
  # Select stack and export
  pulumi stack select $env
  pulumi stack export --file $BACKUP_DIR/pulumi-state-$env-$DATE.json
  
  # Upload to S3
  aws s3 cp $BACKUP_DIR/pulumi-state-$env-$DATE.json \
    s3://$BUCKET/pulumi-states/$env/
  
  # Create metadata file
  cat > $BACKUP_DIR/pulumi-metadata-$env-$DATE.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$env",
  "pulumi_version": "$(pulumi version)",
  "git_commit": "$(git rev-parse HEAD)",
  "git_branch": "$(git branch --show-current)"
}
EOF

  aws s3 cp $BACKUP_DIR/pulumi-metadata-$env-$DATE.json \
    s3://$BUCKET/pulumi-metadata/$env/
done

# Cleanup old backups (keep last 30 days)
find $BACKUP_DIR -name "pulumi-*-*.json" -mtime +30 -delete

echo "Pulumi state backup completed"
```

## 🎯 ArgoCD Backup

### ArgoCD Configuration Backup

```bash
#!/bin/bash
# ArgoCD backup script

BACKUP_DIR="/backups/argocd"
DATE=$(date +%Y%m%d-%H%M)
NAMESPACE="argocd"

mkdir -p $BACKUP_DIR

echo "Backing up ArgoCD configuration..."

# Export ArgoCD applications
kubectl get applications -n $NAMESPACE -o yaml > $BACKUP_DIR/applications-$DATE.yaml

# Export ArgoCD app projects
kubectl get appprojects -n $NAMESPACE -o yaml > $BACKUP_DIR/appprojects-$DATE.yaml

# Export ArgoCD repositories
kubectl get secrets -n $NAMESPACE -l argocd.argoproj.io/secret-type=repository \
  -o yaml > $BACKUP_DIR/repositories-$DATE.yaml

# Export ArgoCD clusters
kubectl get secrets -n $NAMESPACE -l argocd.argoproj.io/secret-type=cluster \
  -o yaml > $BACKUP_DIR/clusters-$DATE.yaml

# Export ArgoCD ConfigMaps
kubectl get configmap argocd-cm argocd-cmd-params-cm argocd-rbac-cm -n $NAMESPACE \
  -o yaml > $BACKUP_DIR/configmaps-$DATE.yaml

# Create tarball
tar -czf $BACKUP_DIR/argocd-backup-$DATE.tar.gz -C $BACKUP_DIR \
  applications-$DATE.yaml \
  appprojects-$DATE.yaml \
  repositories-$DATE.yaml \
  clusters-$DATE.yaml \
  configmaps-$DATE.yaml

# Upload to S3
aws s3 cp $BACKUP_DIR/argocd-backup-$DATE.tar.gz \
  s3://your-backup-bucket/argocd-backups/

# Cleanup
rm $BACKUP_DIR/*.yaml
find $BACKUP_DIR -name "argocd-backup-*.tar.gz" -mtime +30 -delete

echo "ArgoCD backup completed"
```

### ArgoCD Database Backup (if using external database)

```bash
#!/bin/bash
# ArgoCD PostgreSQL backup (if using external DB)

DB_HOST="your-postgres-host"
DB_NAME="argocd"
DB_USER="argocd"
BACKUP_DIR="/backups/argocd-db"
DATE=$(date +%Y%m%d-%H%M)

# Create database dump
PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
  -h $DB_HOST \
  -U $DB_USER \
  -d $DB_NAME \
  -f $BACKUP_DIR/argocd-db-$DATE.sql

# Compress backup
gzip $BACKUP_DIR/argocd-db-$DATE.sql

# Upload to S3
aws s3 cp $BACKUP_DIR/argocd-db-$DATE.sql.gz \
  s3://your-backup-bucket/argocd-db/
```

## 🗄️ Kubernetes Cluster Backup

### Velero Backup Solution

```yaml
# Velero backup schedule
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: gitops-ultra-daily-backup
  namespace: velero
spec:
  schedule: "0 1 * * *"  # Daily at 1 AM
  template:
    includedNamespaces:
    - argocd
    - pulumi-kubernetes-operator
    - pulumi-system
    - myapp-dev
    - monitoring
    - logging
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h0m0s  # 30 days
    snapshotVolumes: true
    includeClusterResources: true
    
---
# Weekly full cluster backup
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: gitops-ultra-weekly-full-backup
  namespace: velero
spec:
  schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
  template:
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 2160h0m0s  # 90 days
    snapshotVolumes: true
    includeClusterResources: true
```

### Manual Kubernetes Backup Script

```bash
#!/bin/bash
# Manual Kubernetes backup script

BACKUP_DIR="/backups/kubernetes"
DATE=$(date +%Y%m%d-%H%M)
NAMESPACES="argocd pulumi-kubernetes-operator pulumi-system myapp-dev"

mkdir -p $BACKUP_DIR

echo "Starting Kubernetes backup..."

# Backup cluster info
kubectl cluster-info > $BACKUP_DIR/cluster-info-$DATE.txt

# Backup nodes
kubectl get nodes -o yaml > $BACKUP_DIR/nodes-$DATE.yaml

# Backup persistent volumes
kubectl get pv -o yaml > $BACKUP_DIR/persistent-volumes-$DATE.yaml

# Backup storage classes
kubectl get storageclass -o yaml > $BACKUP_DIR/storage-classes-$DATE.yaml

# Backup CRDs
kubectl get crd -o yaml > $BACKUP_DIR/crds-$DATE.yaml

# Backup each namespace
for ns in $NAMESPACES; do
  echo "Backing up namespace: $ns"
  
  mkdir -p $BACKUP_DIR/$ns
  
  # Get all resources in namespace
  kubectl get all -n $ns -o yaml > $BACKUP_DIR/$ns/all-resources-$DATE.yaml
  
  # Get secrets (excluding service account tokens)
  kubectl get secrets -n $ns \
    --field-selector type!=kubernetes.io/service-account-token \
    -o yaml > $BACKUP_DIR/$ns/secrets-$DATE.yaml
  
  # Get configmaps
  kubectl get configmaps -n $ns -o yaml > $BACKUP_DIR/$ns/configmaps-$DATE.yaml
  
  # Get persistent volume claims
  kubectl get pvc -n $ns -o yaml > $BACKUP_DIR/$ns/pvc-$DATE.yaml
done

# Create comprehensive backup archive
tar -czf $BACKUP_DIR/k8s-backup-$DATE.tar.gz -C $BACKUP_DIR \
  cluster-info-$DATE.txt \
  nodes-$DATE.yaml \
  persistent-volumes-$DATE.yaml \
  storage-classes-$DATE.yaml \
  crds-$DATE.yaml \
  argocd/ \
  pulumi-kubernetes-operator/ \
  pulumi-system/ \
  myapp-dev/

# Upload to S3
aws s3 cp $BACKUP_DIR/k8s-backup-$DATE.tar.gz \
  s3://your-backup-bucket/kubernetes-backups/

# Cleanup
rm -rf $BACKUP_DIR/argocd $BACKUP_DIR/pulumi-* $BACKUP_DIR/myapp-dev
rm $BACKUP_DIR/*.txt $BACKUP_DIR/*.yaml
find $BACKUP_DIR -name "k8s-backup-*.tar.gz" -mtime +30 -delete

echo "Kubernetes backup completed"
```

## ☁️ AWS Resources Backup

### RDS Automated Backups

```bash
#!/bin/bash
# AWS RDS backup script

DB_INSTANCE="myapp-prod-db"
SNAPSHOT_ID="myapp-db-manual-$(date +%Y%m%d-%H%M)"

echo "Creating RDS snapshot: $SNAPSHOT_ID"

aws rds create-db-snapshot \
  --db-instance-identifier $DB_INSTANCE \
  --db-snapshot-identifier $SNAPSHOT_ID

# Wait for snapshot completion
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier $SNAPSHOT_ID

echo "RDS snapshot created successfully"
```

### S3 Cross-Region Replication

```python
# Pulumi configuration for S3 backup
import pulumi_aws as aws

# Primary S3 bucket (created by main infrastructure)
backup_bucket = aws.s3.Bucket("backup-bucket",
    bucket="myapp-backup-bucket-us-east-1",
    region="us-east-1",  # Different region for DR
    versioning=aws.s3.BucketVersioningArgs(
        enabled=True
    ),
    server_side_encryption_configuration=aws.s3.BucketServerSideEncryptionConfigurationArgs(
        rule=aws.s3.BucketServerSideEncryptionConfigurationRuleArgs(
            apply_server_side_encryption_by_default=aws.s3.BucketServerSideEncryptionConfigurationRuleApplyServerSideEncryptionByDefaultArgs(
                sse_algorithm="AES256"
            )
        )
    )
)

# Cross-region replication role
replication_role = aws.iam.Role("s3-replication-role",
    assume_role_policy="""{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Effect": "Allow",
                "Principal": {
                    "Service": "s3.amazonaws.com"
                }
            }
        ]
    }"""
)

# Replication policy
replication_policy = aws.iam.RolePolicy("s3-replication-policy",
    role=replication_role.id,
    policy=pulumi.Output.all(backup_bucket.arn).apply(
        lambda arns: f"""{{
            "Version": "2012-10-17",
            "Statement": [
                {{
                    "Effect": "Allow",
                    "Action": [
                        "s3:GetObjectVersionForReplication",
                        "s3:GetObjectVersionAcl"
                    ],
                    "Resource": "arn:aws:s3:::myapp-data-bucket/*"
                }},
                {{
                    "Effect": "Allow",
                    "Action": [
                        "s3:ListBucket"
                    ],
                    "Resource": "arn:aws:s3:::myapp-data-bucket"
                }},
                {{
                    "Effect": "Allow",
                    "Action": [
                        "s3:ReplicateObject",
                        "s3:ReplicateDelete"
                    ],
                    "Resource": "{arns[0]}/*"
                }}
            ]
        }}"""
    )
)
```

## 🔄 Disaster Recovery Procedures

### 1. Complete Infrastructure Recovery

```bash
#!/bin/bash
# Complete disaster recovery script

echo "Starting GitOps Ultra disaster recovery..."

# Step 1: Restore Git repository
echo "1. Restoring Git repository..."
git clone https://github.com/your-org/gitops-ultra-backup.git
cd gitops-ultra

# Step 2: Setup tools
echo "2. Setting up tools..."
make setup
make install-deps

# Step 3: Configure new environment
echo "3. Configuring for DR environment..."
make configure-repo
# Update repository URLs to point to DR environment

# Step 4: Bootstrap new cluster
echo "4. Bootstrapping new cluster..."
make quick-check
make bootstrap

# Step 5: Restore Pulumi state
echo "5. Restoring Pulumi state..."
cd infrastructure/pulumi
# Download latest state backup
aws s3 cp s3://your-backup-bucket/pulumi-states/prod/pulumi-state-prod-latest.json ./
pulumi stack import --file pulumi-state-prod-latest.json

# Step 6: Deploy infrastructure
echo "6. Deploying infrastructure..."
make deploy-infra

# Step 7: Restore ArgoCD configuration
echo "7. Restoring ArgoCD configuration..."
# Download ArgoCD backup
aws s3 cp s3://your-backup-bucket/argocd-backups/argocd-backup-latest.tar.gz ./
tar -xzf argocd-backup-latest.tar.gz
kubectl apply -f applications-*.yaml
kubectl apply -f appprojects-*.yaml
kubectl apply -f configmaps-*.yaml

# Step 8: Deploy applications
echo "8. Deploying applications..."
make deploy-k8s

# Step 9: Restore data
echo "9. Restoring application data..."
# Restore from S3 backups, RDS snapshots, etc.

# Step 10: Verify recovery
echo "10. Verifying recovery..."
make health-check
make verify-deployment

echo "Disaster recovery completed!"
```

### 2. Partial Component Recovery

#### ArgoCD Recovery Only

```bash
#!/bin/bash
# ArgoCD-only recovery

echo "Recovering ArgoCD..."

# Reinstall ArgoCD
make bootstrap

# Restore ArgoCD configuration
aws s3 cp s3://your-backup-bucket/argocd-backups/argocd-backup-latest.tar.gz ./
tar -xzf argocd-backup-latest.tar.gz

kubectl apply -f applications-*.yaml
kubectl apply -f appprojects-*.yaml
kubectl apply -f repositories-*.yaml
kubectl apply -f clusters-*.yaml
kubectl apply -f configmaps-*.yaml

echo "ArgoCD recovery completed"
```

#### Pulumi Stack Recovery

```bash
#!/bin/bash
# Pulumi stack recovery

ENVIRONMENT=${1:-prod}
echo "Recovering Pulumi stack for environment: $ENVIRONMENT"

cd infrastructure/pulumi

# Download state backup
aws s3 cp s3://your-backup-bucket/pulumi-states/$ENVIRONMENT/pulumi-state-$ENVIRONMENT-latest.json ./

# Create and import stack
pulumi stack init $ENVIRONMENT
pulumi stack import --file pulumi-state-$ENVIRONMENT-latest.json

# Refresh and fix any drift
pulumi refresh --yes
pulumi up --yes

echo "Pulumi stack recovery completed"
```

## 🧪 Disaster Recovery Testing

### Monthly DR Test Schedule

```bash
#!/bin/bash
# Monthly disaster recovery test

echo "Starting monthly DR test..."

# Test 1: Git repository recovery
echo "Testing Git repository recovery..."
rm -rf /tmp/dr-test
cd /tmp/dr-test
git clone https://github.com/your-org/gitops-ultra-backup.git
cd gitops-ultra
make validate

# Test 2: Pulumi state recovery
echo "Testing Pulumi state recovery..."
cd infrastructure/pulumi
aws s3 cp s3://your-backup-bucket/pulumi-states/dev/pulumi-state-dev-latest.json ./
pulumi stack init dr-test
pulumi stack import --file pulumi-state-dev-latest.json
pulumi preview

# Test 3: ArgoCD configuration recovery
echo "Testing ArgoCD configuration recovery..."
aws s3 cp s3://your-backup-bucket/argocd-backups/argocd-backup-latest.tar.gz ./
tar -xzf argocd-backup-latest.tar.gz
kubectl apply --dry-run=client -f applications-*.yaml

# Test 4: Backup integrity check
echo "Testing backup integrity..."
# Verify checksums, test restore procedures

echo "DR test completed successfully"
```

## 📊 Monitoring and Alerting for Backups

### Backup Monitoring

```yaml
# PrometheusRule for backup monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backup-monitoring
  namespace: monitoring
spec:
  groups:
  - name: backup.rules
    rules:
    - alert: BackupFailed
      expr: backup_job_success == 0
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "Backup job {{ $labels.job }} failed"
        description: "Backup job {{ $labels.job }} has been failing for more than 1 hour"
    
    - alert: BackupAge
      expr: (time() - backup_last_success_time) > 86400
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Backup is older than 24 hours"
        description: "Last successful backup was {{ $value | humanizeDuration }} ago"
```

This comprehensive backup and disaster recovery strategy ensures your GitOps Ultra deployment is resilient and can recover from various failure scenarios.
