#!/usr/bin/env bash
set -euo pipefail

# Manual backup export script
# Exports config snapshots and triggers AWS backups

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-platform-mvp-dev}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUCKET_NAME="${BACKUP_BUCKET:-}"

if [ -z "$BUCKET_NAME" ]; then
    echo "ERROR: Set BACKUP_BUCKET environment variable"
    exit 1
fi

echo "=== Backup Export — $TIMESTAMP ==="

# Export Terraform state info
echo "Exporting Terraform outputs..."
cd terraform/environments/dev
terraform output -json > "/tmp/tf-outputs-${TIMESTAMP}.json"
aws s3 cp "/tmp/tf-outputs-${TIMESTAMP}.json" "s3://${BUCKET_NAME}/exports/terraform/tf-outputs-${TIMESTAMP}.json"
cd - > /dev/null

# Export Kubernetes configs
echo "Exporting Kubernetes resource snapshots..."
for NS in jenkins sonarqube apps; do
    kubectl get all -n "$NS" -o yaml > "/tmp/k8s-${NS}-${TIMESTAMP}.yaml"
    aws s3 cp "/tmp/k8s-${NS}-${TIMESTAMP}.yaml" "s3://${BUCKET_NAME}/exports/kubernetes/${NS}-${TIMESTAMP}.yaml"
done

# Export Helm releases
echo "Exporting Helm release values..."
for RELEASE in jenkins sonarqube; do
    NS=$RELEASE
    helm get values "$RELEASE" -n "$NS" -o yaml > "/tmp/helm-${RELEASE}-${TIMESTAMP}.yaml" 2>/dev/null || true
    aws s3 cp "/tmp/helm-${RELEASE}-${TIMESTAMP}.yaml" "s3://${BUCKET_NAME}/exports/helm/${RELEASE}-values-${TIMESTAMP}.yaml" 2>/dev/null || true
done

# Trigger RDS snapshot
echo "Creating RDS snapshot..."
DB_INSTANCE=$(aws rds describe-db-instances --region "$REGION" \
    --query "DBInstances[?contains(DBInstanceIdentifier, 'sonarqube')].DBInstanceIdentifier" \
    --output text 2>/dev/null || echo "")
if [ -n "$DB_INSTANCE" ]; then
    aws rds create-db-snapshot \
        --db-instance-identifier "$DB_INSTANCE" \
        --db-snapshot-identifier "${DB_INSTANCE}-manual-${TIMESTAMP}" \
        --region "$REGION"
    echo "RDS snapshot initiated: ${DB_INSTANCE}-manual-${TIMESTAMP}"
else
    echo "WARNING: No SonarQube RDS instance found"
fi

# Cleanup temp files
rm -f /tmp/tf-outputs-*.json /tmp/k8s-*.yaml /tmp/helm-*.yaml

echo ""
echo "=== Backup export complete ==="
echo "S3 location: s3://${BUCKET_NAME}/exports/"
