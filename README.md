# Platform Engineering MVP

A reproducible AWS-based internal platform MVP — infrastructure as code, Kubernetes runtime, Jenkins CI/CD, SonarQube quality gates, and Ansible deployment.

## Architecture Overview

```
Internet → ALB (TLS/ACM) → EKS Private Workers
                              ├── Jenkins Controller (EFS persistence, JCasC)
                              ├── Jenkins K8s Agents (ephemeral)
                              ├── SonarQube (RDS PostgreSQL backend)
                              └── Sample App
```

**Subdomains:**
- `jenkins.manoj-tech-solutions.site` — Jenkins CI/CD
- `sonar.manoj-tech-solutions.site` — SonarQube
- `app.manoj-tech-solutions.site` — Sample Application (optional)

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.6 |
| AWS CLI | v2 |
| kubectl | >= 1.29 |
| Helm | >= 3.14 |
| Ansible | >= 2.15 |
| Docker | >= 24.0 |
| jq | >= 1.6 |

Run `scripts/preflight.sh` to verify prerequisites.

## Quick Start

### 1. Set up Terraform Cloud

1. Create workspace `platform-mvp-dev` in your TFC organization
2. Update `REPLACE_WITH_YOUR_TFC_ORG` in `terraform/environments/dev/versions.tf`
3. AWS credentials are handled automatically via OIDC — no static keys needed
4. Set the following variables in TFC:

| Variable | Type | Sensitive | Value |
|----------|------|-----------|-------|
| `rds_password` | Terraform | Yes | Strong password for RDS |
| `jenkins_admin_password` | Terraform | Yes | Jenkins admin password |

### 2. Apply

```bash
cd terraform/environments/dev
terraform login
terraform init
terraform apply
```

A single `terraform apply` provisions all AWS infrastructure **and** deploys all Kubernetes resources (namespaces, controllers, Jenkins, SonarQube) automatically.

### 3. Post-Deploy

After apply completes, Terraform outputs the platform URLs:

```
jenkins_url   = https://jenkins.manoj-tech-solutions.site
sonarqube_url = https://sonar.manoj-tech-solutions.site
```

Generate a SonarQube token (My Account -> Security -> Generate Token), set `sonarqube_token` in TFC, and re-apply to enable Jenkins-SonarQube integration.

### 4. Validate

```bash
scripts/validate.sh
```

## Repository Structure

```
platform-mvp/
├── docs/                          # Architecture docs, runbooks
├── terraform/
│   ├── modules/                   # Reusable Terraform modules
│   │   ├── network/               # VPC, subnets, NAT, routing
│   │   ├── eks/                   # EKS cluster + node groups
│   │   ├── iam/                   # IAM roles, IRSA
│   │   ├── efs/                   # EFS for Jenkins persistence
│   │   ├── rds_postgres/          # PostgreSQL for SonarQube
│   │   ├── ecr/                   # Container registries
│   │   ├── codeartifact/          # Package management
│   │   ├── route53_acm/           # DNS + TLS certificates
│   │   ├── alb-prereqs/           # ALB security groups
│   │   ├── ansible_runner/        # Dedicated Ansible EC2
│   │   ├── s3_backup/             # Backup storage
│   │   └── backup/                # AWS Backup plans
│   └── environments/dev/          # Dev environment composition
├── kubernetes/
│   ├── base/                      # Namespaces, storage classes
│   ├── controllers/               # ALB controller, EFS CSI, ExternalDNS
│   ├── platform/                  # Jenkins + SonarQube Helm configs (reference)
│   └── apps/                      # Sample application
├── jenkins/
│   ├── shared-library/            # Reusable pipeline functions
│   ├── job-dsl/                   # Job bootstrap
│   └── Jenkinsfile.sample         # Demo pipeline
├── ansible/                       # Deployment playbooks and roles
├── scripts/                       # Preflight, validation, backup
└── .github/workflows/             # CI validation
```

## Design Principles

1. **Single apply** -- One `terraform apply` provisions all infra and K8s resources
2. **Decoupled layers** -- Terraform for infra, Helm for apps, JCasC for Jenkins config
3. **Idempotent** -- All operations converge on repeated runs
4. **Replaceable** -- Any component rebuildable from code
5. **Secure** -- Private workers, no public SSH, SSM access only, least-privilege IAM, TLS everywhere
6. **Extensible** -- Ready for additional environments, SonarQube DCE, CloudBees, Secrets Manager
