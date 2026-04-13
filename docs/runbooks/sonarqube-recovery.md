# SonarQube Recovery Runbook

## Scenario: SonarQube Pod Failure

**Impact:** Code quality scans fail, quality gate checks time out.

### Steps

1. **Check pod status:**
   ```bash
   kubectl get pods -n sonarqube
   kubectl describe pod -n sonarqube -l app=sonarqube
   kubectl logs -n sonarqube -l app=sonarqube --tail=100
   ```

2. **Common issue: vm.max_map_count too low**
   The init container should handle this, but verify:
   ```bash
   kubectl exec -n sonarqube <pod> -- cat /proc/sys/vm/max_map_count
   ```

3. **If pod is stuck, delete and let it reschedule:**
   ```bash
   kubectl delete pod -n sonarqube -l app=sonarqube
   ```

4. **Redeploy via Helm:**
   ```bash
   helm upgrade --install sonarqube sonarqube/sonarqube \
     -n sonarqube -f kubernetes/platform/sonarqube/values.yaml
   ```

## Scenario: RDS Database Failure

1. **Check RDS status:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier platform-mvp-sonarqube \
     --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'
   ```

2. **If RDS is unavailable, check events:**
   ```bash
   aws rds describe-events \
     --source-identifier platform-mvp-sonarqube \
     --source-type db-instance --duration 60
   ```

3. **Restore from snapshot:**
   ```bash
   # List available snapshots
   aws rds describe-db-snapshots \
     --db-instance-identifier platform-mvp-sonarqube \
     --query 'DBSnapshots[].{Time:SnapshotCreateTime,ID:DBSnapshotIdentifier}' \
     --output table

   # Restore to new instance
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier platform-mvp-sonarqube-restored \
     --db-snapshot-identifier <SNAPSHOT_ID> \
     --db-subnet-group-name platform-mvp-rds-subnet-group \
     --vpc-security-group-ids <RDS_SG_ID>
   ```

4. **Update SonarQube Helm values** with new RDS endpoint if restored to new instance.

5. **Redeploy SonarQube** and verify connectivity:
   ```bash
   curl -sk https://sonar.manoj-tech-solutions.site/api/system/status
   ```

## Scenario: Full Rebuild

1. `terraform apply` — recreates RDS (data from last automated backup)
2. `helm upgrade --install sonarqube ...`
3. Verify: `curl https://sonar.manoj-tech-solutions.site/api/system/status`
4. Re-generate SonarQube token for Jenkins if needed
