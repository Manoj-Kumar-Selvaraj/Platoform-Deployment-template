# Backup and Recovery Strategy

## Overview

Recovery follows a tiered approach:
1. **Infrastructure** — Rebuilt from Terraform
2. **Platform config** — Rebuilt from Helm + JCasC + Job DSL
3. **Runtime state** — Restored from EFS/RDS backups
4. **Artifacts** — Retained via managed service policies

## Jenkins

### What's Backed Up
| Data | Location | Backup Method |
|------|----------|--------------|
| Configuration | Git (JCasC, plugins.txt) | Git history |
| Jobs/Pipelines | Git (Job DSL, Jenkinsfile) | Git history |
| Runtime state | EFS | AWS Backup (daily) |
| Build history | EFS | AWS Backup (daily) |
| Credentials | K8s Secrets | Must be re-provisioned or backed up separately |

### Recovery Procedure
See `runbooks/jenkins-recovery.md`

### Backup Schedule
- **AWS Backup**: Daily at 03:00 UTC, 35-day retention
- **Pre-upgrade**: Manual backup via `scripts/backup_export.sh` before major upgrades

## SonarQube

### What's Backed Up
| Data | Location | Backup Method |
|------|----------|--------------|
| Analysis data | RDS PostgreSQL | Automated snapshots (7-day retention) |
| Configuration | Helm values (Git) | Git history |
| Runtime | EKS (stateless) | Redeployable from Helm |

### Recovery Procedure
See `runbooks/sonarqube-recovery.md`

## S3 Backup Bucket

- Versioning enabled — accidental deletes recoverable
- Lifecycle: Standard → IA (30 days) → Glacier (90 days) → Expire (365 days)
- Encryption: AES-256 server-side
- Public access: Blocked

## ECR

- Lifecycle policy: Keep last 30 tagged images, expire untagged > 7 days
- Image scanning on push

## Disaster Recovery Scope (MVP)

| Scenario | Recovery |
|----------|---------|
| Pod crash | Kubernetes reschedules automatically |
| Node failure | EKS replaces via managed node group |
| EFS data loss | Restore from AWS Backup |
| RDS failure | Automated failover / restore from snapshot |
| Full cluster loss | Terraform apply + Helm deploys + restore backups |
| Region failure | Out of scope (future Azure DR) |
