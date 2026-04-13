# Jenkins Recovery Runbook

## Scenario: Jenkins Pod/Node Failure

**Impact:** Jenkins controller inaccessible, builds cannot start.

### Automatic Recovery
EKS will reschedule the Jenkins pod automatically if only the pod crashed. Jenkins home is on EFS, so state persists.

### Manual Recovery Steps

1. **Check pod status:**
   ```bash
   kubectl get pods -n jenkins
   kubectl describe pod -n jenkins -l app.kubernetes.io/name=jenkins
   kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins --tail=100
   ```

2. **If pod is stuck, delete and let it reschedule:**
   ```bash
   kubectl delete pod -n jenkins -l app.kubernetes.io/name=jenkins
   ```

3. **If Helm release is corrupted, redeploy:**
   ```bash
   helm upgrade --install jenkins jenkins/jenkins \
     -n jenkins -f kubernetes/platform/jenkins/values.yaml
   ```

4. **Verify JCasC loaded:**
   - Access https://jenkins.manoj-tech-solutions.site/manage
   - Check "Configuration as Code" section shows no errors

5. **Verify agents can start:**
   - Trigger a test build
   - Check pod creation in jenkins namespace: `kubectl get pods -n jenkins -w`

## Scenario: EFS Data Loss

1. **List available backups:**
   ```bash
   aws backup list-recovery-points-by-backup-vault \
     --backup-vault-name platform-mvp-backup-vault \
     --query 'RecoveryPoints[].{Time:CreationDate,Status:Status,ARN:RecoveryPointArn}' \
     --output table
   ```

2. **Start restore job:**
   ```bash
   aws backup start-restore-job \
     --recovery-point-arn <RECOVERY_POINT_ARN> \
     --iam-role-arn <BACKUP_ROLE_ARN> \
     --metadata '{"file-system-id":"<NEW_EFS_ID>","newFileSystem":"true","CreationToken":"jenkins-restore","PerformanceMode":"generalPurpose"}'
   ```

3. **Update EFS ID** in storage class and Jenkins PV/PVC if restored to new filesystem.

4. **Restart Jenkins pod** to pick up restored data.

## Scenario: Full Rebuild

1. `terraform apply` to rebuild infrastructure
2. `kubectl apply -f kubernetes/base/`
3. Deploy controllers (ALB, EFS CSI, ExternalDNS)
4. `helm upgrade --install jenkins ...`
5. Restore EFS from AWS Backup if needed
6. Jenkins JCasC will rebuild all configuration
7. Seed job will recreate multibranch pipelines
