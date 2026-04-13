# Platform MVP — Deployment Guide (Automated)

One `terraform apply` provisions **everything**: AWS infra, EKS cluster, controllers, Jenkins, SonarQube, secrets, DNS, TLS, backups.

---

## What You Do vs What Terraform Does

| You Do (Manual, One-Time) | Terraform Does (Automated) |
|---|---|
| Create TFC workspace | VPC, subnets, NAT, IGW, route tables |
| Set 3 sensitive variables in TFC | EKS cluster + 2 node groups |
| Edit TFC org name in versions.tf | EFS + mount targets + access point |
| `terraform apply` | RDS PostgreSQL |
| | ACM wildcard cert + DNS validation |
| | ECR repositories + lifecycle |
| | CodeArtifact domain + repos |
| | S3 backup bucket + lifecycle |
| | AWS Backup vault + daily plan |
| | Ansible runner EC2 (SSM) |
| | IAM roles + IRSA |
| | K8s namespaces (jenkins, sonarqube, apps) |
| | EFS StorageClass |
| | AWS Load Balancer Controller (Helm) |
| | EFS CSI Driver (Helm) |
| | ExternalDNS (Helm) |
| | SonarQube (Helm) + DB secret |
| | Jenkins (Helm) + admin secret + plugins + JCasC |
| | DNS records via ExternalDNS |

---

## Step 1: Set Up Terraform Cloud (5 min)

### 1.1 Create TFC workspace

1. Go to https://app.terraform.io
2. Create an organization (if you don't have one)
3. Create workspace: **CLI-driven**, name: `platform-mvp-dev`

### 1.2 Edit `versions.tf`

```bash
cd d:/Manoj/Projects/Platform-Setup/platform-mvp/terraform/environments/dev
```

Edit `versions.tf` line 4 — replace `REPLACE_WITH_YOUR_TFC_ORG` with your TFC organization name.

### 1.3 Set TFC Variables

In your TFC workspace → **Variables** tab, add:

**Terraform Variables (sensitive):**

| Key | Category | Sensitive | Value |
|-----|----------|-----------|-------|
| `rds_password` | terraform | Yes | A strong password (8+ chars, alphanumeric) |
| `jenkins_admin_password` | terraform | Yes | Jenkins admin password |
| `domain_name` | terraform | No | `manoj-tech-solutions.site` |

**Environment Variables:**

| Key | Category | Sensitive | Value |
|-----|----------|-----------|-------|
| `AWS_ACCESS_KEY_ID` | env | Yes | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | env | Yes | Your AWS secret key |
| `AWS_DEFAULT_REGION` | env | No | `us-east-1` |

> All other variables have sensible defaults. See `terraform.tfvars.example` for the full list.

### 1.4 Login to TFC locally

```bash
terraform login
```

---

## Step 2: Deploy Everything (25-30 min)

```bash
cd terraform/environments/dev

terraform init
terraform plan     # Review — should show ~80-100 resources
terraform apply    # Type 'yes'
```

**What happens in order:**
1. (~2 min) VPC, subnets, IGW, NAT Gateway, route tables
2. (~1 min) IAM roles, security groups, S3, ECR, CodeArtifact
3. (~15 min) EKS cluster + node groups, RDS PostgreSQL
4. (~1 min) EFS, ACM certificate, AWS Backup, Ansible runner
5. (~1 min) Wait for nodes to register
6. (~3 min) Helm: ALB Controller, EFS CSI, ExternalDNS
7. (~5 min) Helm: SonarQube (waits for RDS + ALB controller)
8. (~5 min) Helm: Jenkins (waits for EFS storage class + SonarQube)

### Output

After apply, Terraform prints:

```
jenkins_url    = "https://jenkins.manoj-tech-solutions.site"
sonarqube_url  = "https://sonar.manoj-tech-solutions.site"
next_steps     = "..."
```

---

## Step 3: Access Your Platform (3-5 min after apply)

DNS propagation via ExternalDNS takes 1-3 minutes.

### Jenkins
```
URL:      https://jenkins.manoj-tech-solutions.site
Username: admin (or whatever you set)
Password: (the jenkins_admin_password you set in TFC)
```

Verify:
- System message says "Managed by Terraform + JCasC"
- Executors = 0
- Kubernetes cloud configured
- SonarQube plugin installed

### SonarQube
```
URL:      https://sonar.manoj-tech-solutions.site
Username: admin
Password: admin (CHANGE THIS on first login!)
```

---

## Step 4: Connect Jenkins ↔ SonarQube (5 min)

This is the one connection that requires a manual step on first deploy because SonarQube must be running to generate a token.

1. Log into SonarQube → **My Account → Security**
2. Generate Token: name=`jenkins`, type=`Global Analysis Token`
3. Copy the token
4. In TFC workspace → Variables, add:
   - Key: `sonarqube_token`, Value: the token, Sensitive: Yes
5. Re-run:
   ```bash
   terraform apply
   ```
   This updates Jenkins JCasC with the real SonarQube token.

---

## Step 5: Deploy Sample App (Optional, 5 min)

### 5.1 Build and push the image

```bash
# Get ECR URL from Terraform
ECR_URL=$(terraform output -json ecr_repository_urls | jq -r '."sample-app"')
ECR_REGISTRY=$(echo $ECR_URL | cut -d/ -f1)

# Login + build + push
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

cd ../../../../kubernetes/apps/sample-app/src
docker build -t $ECR_URL:v1 .
docker push $ECR_URL:v1
```

### 5.2 Enable sample app in Terraform

In TFC Variables (or re-apply with):
```bash
terraform apply -var="deploy_sample_app=true" -var="sample_app_image_tag=v1"
```

Access: https://app.manoj-tech-solutions.site/health

---

## Step 6: Verify Everything

### Quick check
```bash
# Configure kubectl
$(terraform output -raw kubeconfig_command)

# Check all pods
kubectl get pods -A

# Check Helm releases
helm list -A
```

### Full validation
```bash
cd ../../../
chmod +x scripts/validate.sh
./scripts/validate.sh
```

---

## Complete TFC Variable Reference

### Required (must set before first apply)

| Variable | Type | Sensitive | Description |
|----------|------|-----------|-------------|
| `rds_password` | terraform | Yes | PostgreSQL password for SonarQube |
| `jenkins_admin_password` | terraform | Yes | Jenkins admin password |
| `AWS_ACCESS_KEY_ID` | env | Yes | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | env | Yes | AWS credentials |

### Optional (set after first deploy)

| Variable | Type | Sensitive | Description |
|----------|------|-----------|-------------|
| `sonarqube_token` | terraform | Yes | SonarQube token for Jenkins (after Step 4) |
| `deploy_sample_app` | terraform | No | `true` to deploy sample app (after Step 5) |
| `sample_app_image_tag` | terraform | No | Image tag in ECR |

### All have defaults (override if needed)

| Variable | Default | Description |
|----------|---------|-------------|
| `domain_name` | (required) | Your domain |
| `aws_region` | `us-east-1` | AWS region |
| `cluster_name` | `platform-mvp-dev` | EKS cluster name |
| `kubernetes_version` | `1.29` | K8s version |
| `enable_codeartifact` | `true` | Feature flag |
| See `variables.tf` for full list | | |

---

## Lifecycle Operations

### Update Jenkins/SonarQube config
Edit `kubernetes.tf` → `terraform apply`

### Scale node groups
Change `platform_control_desired` / `platform_exec_max` in TFC → `terraform apply`

### Add a new ECR repo
Add to `ecr_repository_names` list → `terraform apply`

### Disable CodeArtifact
Set `enable_codeartifact = false` → `terraform apply`

### Full teardown
```bash
terraform destroy
```
> Destroys EVERYTHING including data. Back up first!

---

## Architecture of the Automation

```
terraform apply
  │
  ├── AWS Infrastructure (modules)
  │     ├── network (VPC, subnets, NAT)
  │     ├── iam (roles, IRSA)
  │     ├── eks (cluster, node groups, OIDC)
  │     ├── efs (filesystem, mount targets)
  │     ├── rds_postgres (PostgreSQL)
  │     ├── route53_acm (cert, DNS validation)
  │     ├── ecr (container registries)
  │     ├── codeartifact (package repos)
  │     ├── s3_backup (backup bucket)
  │     ├── backup (AWS Backup plan)
  │     ├── alb-prereqs (security groups)
  │     └── ansible_runner (EC2)
  │
  ├── kubernetes.tf (Helm + K8s provider)
  │     ├── time_sleep (wait for nodes)
  │     ├── kubernetes_namespace × 3
  │     ├── helm_release: aws-load-balancer-controller
  │     ├── helm_release: aws-efs-csi-driver
  │     ├── helm_release: external-dns
  │     ├── kubernetes_storage_class: efs-sc
  │     ├── kubernetes_secret: sonarqube-db-credentials
  │     ├── helm_release: sonarqube
  │     ├── kubernetes_secret: jenkins-admin-credentials
  │     ├── kubernetes_secret: jenkins-sonarqube-token
  │     ├── helm_release: jenkins
  │     └── helm_release: sample-app (optional)
  │
  └── Outputs: URLs, kubectl command, next steps
```
