# Assumptions and Constraints

## AWS Account
- A valid AWS account with sufficient permissions exists
- The caller has AdministratorAccess or equivalent for initial provisioning
- `us-east-1` is the target region
- Terraform Cloud is used for state management

## Domain
- `manoj-tech-solutions.site` is registered and has a Route53 hosted zone
- The hosted zone is in the same AWS account
- Wildcard certificate `*.manoj-tech-solutions.site` will be used for all subdomains

## Networking
- Single region, two Availability Zones
- One NAT Gateway for MVP (cost optimization); extensible to one-per-AZ
- VPC CIDR 10.10.0.0/16 does not conflict with other networks
- No VPN or Direct Connect required for MVP

## EKS
- Kubernetes version 1.29+
- Managed node groups (not Fargate or self-managed)
- Two node groups: platform-control (tainted) and platform-exec
- Public API endpoint enabled with optional CIDR restriction

## Jenkins
- Open Source Jenkins (not CloudBees)
- Single controller — HA-capable (not active-active)
- JCasC is the primary configuration mechanism
- Plugins are pinned in code
- 0 executors on controller — all builds on K8s agents
- EFS for persistent storage (/var/jenkins_home)

## SonarQube
- Community or Developer Edition (single instance)
- External RDS PostgreSQL for database
- Not Data Center Edition (future upgrade path preserved)

## Ansible
- Dedicated EC2 runner in private subnet
- SSM connection plugin for AWS targets
- SSH for on-prem targets (stub inventory provided)
- Runner bootstrapped via user data

## Security
- No enterprise SSO for MVP — local Jenkins auth via JCasC
- SonarQube default auth with admin token for Jenkins integration
- Secrets managed via Kubernetes Secrets (Secrets Manager ready)
- No WAF for MVP

## Cost Considerations
- Single NAT Gateway (~$32/month)
- t3.large x2 for platform-control (~$120/month)
- t3.medium x1-5 for platform-exec (~$30-150/month)
- db.t3.medium RDS (~$50/month)
- t3.small Ansible runner (~$15/month)
- EFS, S3, ECR — usage-based
- Estimated MVP cost: ~$300-500/month
