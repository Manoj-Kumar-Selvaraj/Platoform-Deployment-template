# Architecture Overview

## Component Diagram

```
                                  ┌─────────────────────────────────────┐
                                  │           Route53 DNS               │
                                  │  jenkins.manoj-tech-solutions.site  │
                                  │  sonar.manoj-tech-solutions.site    │
                                  └──────────────┬──────────────────────┘
                                                 │
                                  ┌──────────────▼──────────────────────┐
                                  │     Application Load Balancer       │
                                  │     (TLS termination via ACM)       │
                                  │     Host-based routing              │
                                  └──────────────┬──────────────────────┘
                                                 │
                    ┌────────────────────────────────────────────────────────────┐
                    │                        VPC 10.10.0.0/16                    │
                    │  ┌─────────────────────────────────────────────────────┐   │
                    │  │              Public Subnets                         │   │
                    │  │  10.10.1.0/24 (AZ1)    10.10.2.0/24 (AZ2)         │   │
                    │  │  [NAT Gateway]          [ALB Nodes]                │   │
                    │  └─────────────────────────────────────────────────────┘   │
                    │  ┌─────────────────────────────────────────────────────┐   │
                    │  │              Private Subnets                        │   │
                    │  │  10.10.11.0/24 (AZ1)   10.10.12.0/24 (AZ2)        │   │
                    │  │  ┌──────────────────────────────────────────────┐   │   │
                    │  │  │              EKS Cluster                     │   │   │
                    │  │  │  ┌────────────────────────────────────────┐  │   │   │
                    │  │  │  │ platform-control nodes (t3.large)     │  │   │   │
                    │  │  │  │  ├── Jenkins Controller (EFS mount)   │  │   │   │
                    │  │  │  │  └── SonarQube (RDS connection)       │  │   │   │
                    │  │  │  ├────────────────────────────────────────┤  │   │   │
                    │  │  │  │ platform-exec nodes (t3.medium)       │  │   │   │
                    │  │  │  │  ├── Jenkins K8s Agents (ephemeral)   │  │   │   │
                    │  │  │  │  └── Sample App Pods                  │  │   │   │
                    │  │  │  └────────────────────────────────────────┘  │   │   │
                    │  │  │                                              │   │   │
                    │  │  │  [Ansible Runner EC2]  [RDS PostgreSQL]     │   │   │
                    │  │  │  (SSM-managed)          (SonarQube DB)      │   │   │
                    │  │  └──────────────────────────────────────────────┘   │   │
                    │  └─────────────────────────────────────────────────────┘   │
                    └────────────────────────────────────────────────────────────┘

                    External Services:
                    ├── ECR (container images)
                    ├── CodeArtifact (package management)
                    ├── EFS (Jenkins persistence)
                    ├── S3 (backup exports)
                    └── AWS Backup (EFS scheduled backups)
```

## Traffic Flow

1. User requests `jenkins.manoj-tech-solutions.site`
2. Route53 resolves to ALB
3. ALB terminates TLS using ACM wildcard certificate
4. ALB routes based on host header to target group
5. AWS Load Balancer Controller manages target groups via Ingress resources
6. Traffic reaches Jenkins/SonarQube ClusterIP services inside EKS

## CI/CD Flow

1. Developer pushes code to Git repository
2. Jenkins detects change (webhook or poll)
3. Jenkins launches ephemeral K8s agent on platform-exec nodes
4. Agent executes pipeline: build → test → SonarQube scan → Docker build → ECR push → Helm deploy
5. Optional: Jenkins triggers Ansible on runner via SSM for EC2/on-prem deployments

## Persistence Strategy

| Component | Persistence | Backup |
|-----------|------------|--------|
| Jenkins config | JCasC + Git (primary), EFS (runtime state) | AWS Backup daily |
| Jenkins jobs | Job DSL / Multibranch (primary) | N/A — rebuilt from code |
| SonarQube data | RDS PostgreSQL | RDS automated snapshots |
| Container images | ECR | Lifecycle policy retention |
| Packages | CodeArtifact | Managed service |
| Exports | S3 | Versioning + lifecycle |

## Security Boundaries

- No public worker nodes — all EKS nodes in private subnets
- ALB is the only public entry point
- TLS on all public endpoints
- SSM for EC2 administration — no SSH required
- IRSA for pod-level AWS permissions
- No secrets in Git — K8s Secrets + JCasC interpolation
