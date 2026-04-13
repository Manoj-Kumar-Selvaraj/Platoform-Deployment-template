# ================================================================
# kubernetes.tf — Full K8s automation via Terraform
# Single terraform apply provisions everything on EKS
#
# NOTE: This file is identical to environments/dev/kubernetes.tf.
#   - SonarQube JDBC URL: conditional on var.rds_endpoint_override
#   - Velero: gated on var.enable_velero (default true in DR)
#   - All other resources: identical to dev
# ================================================================

# Ensure node groups are ready before deploying anything to K8s.
# The time_sleep gives nodes ~60s to register after Terraform
# reports node groups as created.
resource "time_sleep" "wait_for_nodes" {
  depends_on = [module.eks]

  create_duration = "120s"
}

# ================================================================
# 1. NAMESPACES
# ================================================================
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }
  depends_on = [time_sleep.wait_for_nodes]
}

resource "kubernetes_namespace" "sonarqube" {
  metadata {
    name = "sonarqube"
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }
  depends_on = [time_sleep.wait_for_nodes]
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }
  depends_on = [time_sleep.wait_for_nodes]
}

# ================================================================
# VELERO — Kubernetes-level backup to S3 (cross-region replicated)
# Gated on var.enable_velero — enable after S3 CRR is set up
# ================================================================

resource "kubernetes_namespace" "velero" {
  count = var.enable_velero ? 1 : 0

  metadata {
    name = "velero"
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }
  depends_on = [time_sleep.wait_for_nodes]
}

resource "helm_release" "velero" {
  count      = var.enable_velero ? 1 : 0
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  namespace  = kubernetes_namespace.velero[0].metadata[0].name
  version    = "7.0.0"
  timeout    = 600

  # AWS plugin init container
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-aws"
  }
  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-aws:v1.10.0"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }

  # EFS uses filesystem backup (no CSI snapshots supported)
  set {
    name  = "configuration.defaultVolumesToFsBackup"
    value = "true"
    type  = "string"
  }
  set {
    name  = "configuration.uploaderType"
    value = "kopia"
  }
  set {
    name  = "deployNodeAgent"
    value = "true"
    type  = "string"
  }

  # Backup storage location → primary S3 bucket (replicated to DR via CRR)
  set {
    name  = "configuration.backupStorageLocation[0].name"
    value = "default"
  }
  set {
    name  = "configuration.backupStorageLocation[0].provider"
    value = "aws"
  }
  set {
    name  = "configuration.backupStorageLocation[0].bucket"
    value = module.s3_backup.bucket_name
  }
  set {
    name  = "configuration.backupStorageLocation[0].prefix"
    value = "velero"
  }
  set {
    name  = "configuration.backupStorageLocation[0].config.region"
    value = var.aws_region
  }

  # Volume snapshot location
  set {
    name  = "configuration.volumeSnapshotLocation[0].name"
    value = "default"
  }
  set {
    name  = "configuration.volumeSnapshotLocation[0].provider"
    value = "aws"
  }
  set {
    name  = "configuration.volumeSnapshotLocation[0].config.region"
    value = var.aws_region
  }

  # IRSA
  set {
    name  = "serviceAccount.server.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.velero_role_arn
  }

  # Daily backup schedule — runs at 02:00 UTC (1h before AWS Backup)
  set {
    name  = "schedules.daily-platform-backup.disabled"
    value = "false"
    type  = "string"
  }
  set {
    name  = "schedules.daily-platform-backup.schedule"
    value = "0 2 * * *"
  }
  set {
    name  = "schedules.daily-platform-backup.template.ttl"
    value = "720h" # 30 days
  }
  set {
    name  = "schedules.daily-platform-backup.template.includedNamespaces[0]"
    value = "jenkins"
  }
  set {
    name  = "schedules.daily-platform-backup.template.includedNamespaces[1]"
    value = "sonarqube"
  }
  set {
    name  = "schedules.daily-platform-backup.template.includedNamespaces[2]"
    value = "artifactory"
  }

  # Scheduling
  set {
    name  = "nodeSelector.role"
    value = "platform-control"
  }
  set {
    name  = "tolerations[0].key"
    value = "platform-control"
  }
  set {
    name  = "tolerations[0].value"
    value = "true"
    type  = "string"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [
    time_sleep.wait_for_nodes,
    helm_release.efs_csi_driver,
    module.s3_backup,
  ]
}

# ================================================================
# 2. STORAGE CLASS — EFS
# ================================================================
resource "kubernetes_storage_class" "efs" {
  metadata {
    name = "efs-sc"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = module.efs.efs_id
    directoryPerms   = "700"
  }

  depends_on = [helm_release.efs_csi_driver]
}

# ================================================================
# 3. EKS CONTROLLERS (Helm)
# ================================================================

# --- AWS Load Balancer Controller ---
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"
  timeout    = 600
  wait       = false

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.network.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.alb_controller_role_arn
  }

  set {
    name  = "replicaCount"
    value = "2"
  }

  set {
    name  = "nodeSelector.role"
    value = "platform-control"
  }

  set {
    name  = "tolerations[0].key"
    value = "platform-control"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
    type  = "string"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [time_sleep.wait_for_nodes]
}

# --- EFS CSI Driver ---
resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "3.0.5"
  timeout    = 600

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.efs_csi_role_arn
  }

  depends_on = [time_sleep.wait_for_nodes]
}

# --- ExternalDNS ---
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.14.3"
  timeout    = 600

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = var.aws_region
  }

  set {
    name  = "aws.zoneType"
    value = "public"
  }

  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "registry"
    value = "txt"
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.external_dns_role_arn
  }

  set {
    name  = "nodeSelector.role"
    value = "platform-control"
  }

  set {
    name  = "tolerations[0].key"
    value = "platform-control"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
    type  = "string"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [time_sleep.wait_for_nodes]
}

# ================================================================
# 4. SONARQUBE
# ================================================================

# --- SonarQube DB credentials secret ---
resource "kubernetes_secret" "sonarqube_db" {
  metadata {
    name      = "sonarqube-db-credentials"
    namespace = kubernetes_namespace.sonarqube.metadata[0].name
  }

  data = {
    password = var.rds_password
  }
}

# --- SonarQube Helm release ---
resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart      = "sonarqube"
  namespace  = kubernetes_namespace.sonarqube.metadata[0].name
  version    = "10.4.0"
  timeout    = 600
  force_update = true

  # Edition
  set {
    name  = "edition"
    value = "community"
  }

  # Disable embedded PostgreSQL — use RDS
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "jdbcOverwrite.enable"
    value = "true"
  }

  set {
    name  = "jdbcOverwrite.jdbcUrl"
    value = var.rds_endpoint_override != "" ? "jdbc:postgresql://${var.rds_endpoint_override}:5432/${var.rds_db_name}" : "jdbc:postgresql://${module.rds_postgres.address}:5432/${var.rds_db_name}"
  }

  set {
    name  = "jdbcOverwrite.jdbcUsername"
    value = var.rds_username
  }

  set {
    name  = "jdbcOverwrite.jdbcSecretName"
    value = kubernetes_secret.sonarqube_db.metadata[0].name
  }

  set {
    name  = "jdbcOverwrite.jdbcSecretPasswordKey"
    value = "password"
  }

  # Ingress — ALB
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = module.route53_acm.certificate_arn
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTPS\": 443}]"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
    type  = "string"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name"
    value = "platform-ingress"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"
    value = "/api/system/status"
  }

  set {
    name  = "ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "sonar.${var.domain_name}"
  }

  set {
    name  = "ingress.hosts[0].name"
    value = "sonar.${var.domain_name}"
  }

  set {
    name  = "ingress.hosts[0].path"
    value = "/*"
  }

  # Scheduling
  set {
    name  = "nodeSelector.role"
    value = "platform-control"
  }

  set {
    name  = "tolerations[0].key"
    value = "platform-control"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
    type  = "string"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # Resources
  set {
    name  = "resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "resources.requests.memory"
    value = "2Gi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "2"
  }

  set {
    name  = "resources.limits.memory"
    value = "4Gi"
  }

  # Sysctl init
  set {
    name  = "initSysctl.enabled"
    value = "true"
  }

  set {
    name  = "initSysctl.vmMaxMapCount"
    value = "524288"
  }

  depends_on = [
    helm_release.aws_lb_controller,
    helm_release.external_dns,
    module.rds_postgres,
  ]
}

# ================================================================
# 5. JFROG ARTIFACTORY OSS
# ================================================================

resource "kubernetes_namespace" "artifactory" {
  metadata {
    name = "artifactory"
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }
  depends_on = [time_sleep.wait_for_nodes]
}

resource "helm_release" "artifactory_oss" {
  name       = "artifactory-oss"
  repository = "https://charts.jfrog.io"
  chart      = "artifactory-oss"
  namespace  = kubernetes_namespace.artifactory.metadata[0].name
  version    = "107.90.8"
  timeout    = 900
  wait       = false

  # Disable bundled PostgreSQL — use embedded Derby for OSS (stateless enough)
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "artifactory.persistence.enabled"
    value = "true"
  }

  set {
    name  = "artifactory.persistence.storageClassName"
    value = "efs-sc"
  }

  set {
    name  = "artifactory.persistence.accessMode"
    value = "ReadWriteMany"
  }

  set {
    name  = "artifactory.persistence.size"
    value = "50Gi"
  }

  # Ingress — ALB (shared group)
  set {
    name  = "artifactory.ingress.enabled"
    value = "true"
  }

  set {
    name  = "artifactory.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = module.route53_acm.certificate_arn
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTPS\": 443}]"
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
    type  = "string"
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name"
    value = "platform-ingress"
  }

  set {
    name  = "artifactory.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"
    value = "/artifactory/api/system/ping"
  }

  set {
    name  = "artifactory.ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "artifactory.${var.domain_name}"
  }

  set {
    name  = "artifactory.ingress.hosts[0]"
    value = "artifactory.${var.domain_name}"
  }

  set {
    name  = "artifactory.ingress.path"
    value = "/*"
  }

  # Scheduling — platform-control nodes
  set {
    name  = "artifactory.nodeSelector.role"
    value = "platform-control"
  }

  set {
    name  = "artifactory.tolerations[0].key"
    value = "platform-control"
  }

  set {
    name  = "artifactory.tolerations[0].value"
    value = "true"
    type  = "string"
  }

  set {
    name  = "artifactory.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Resources
  set {
    name  = "artifactory.resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "artifactory.resources.requests.memory"
    value = "2Gi"
  }

  set {
    name  = "artifactory.resources.limits.cpu"
    value = "2"
  }

  set {
    name  = "artifactory.resources.limits.memory"
    value = "4Gi"
  }

  depends_on = [
    helm_release.aws_lb_controller,
    helm_release.external_dns,
    helm_release.efs_csi_driver,
    kubernetes_storage_class.efs,
  ]
}

# ================================================================
# 6. JENKINS
# ================================================================

# --- Jenkins Kubernetes secrets ---
resource "kubernetes_secret" "jenkins_admin" {
  metadata {
    name      = "jenkins-admin-credentials"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  data = {
    jenkins-admin-user     = var.jenkins_admin_user
    jenkins-admin-password = var.jenkins_admin_password
  }
}

resource "kubernetes_secret" "jenkins_sonarqube" {
  metadata {
    name      = "jenkins-sonarqube-token"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  data = {
    sonarqube-token = var.sonarqube_token
  }
}

# --- Jenkins Helm release ---
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  version    = "5.1.5"
  timeout    = 600
  force_update = true

  # Controller image
  set {
    name  = "controller.image.registry"
    value = "docker.io"
  }

  set {
    name  = "controller.image.repository"
    value = "jenkins/jenkins"
  }

  set {
    name  = "controller.image.tag"
    value = "lts-jdk17"
  }

  # Executors
  set {
    name  = "controller.numExecutors"
    value = "0"
    type  = "string"
  }

  # Admin credentials from secret
  set {
    name  = "controller.admin.existingSecret"
    value = kubernetes_secret.jenkins_admin.metadata[0].name
  }

  set {
    name  = "controller.admin.userKey"
    value = "jenkins-admin-user"
  }

  set {
    name  = "controller.admin.passwordKey"
    value = "jenkins-admin-password"
  }

  # Jenkins URL
  set {
    name  = "controller.jenkinsUrl"
    value = "https://jenkins.${var.domain_name}"
  }

  # Install plugins
  set {
    name  = "controller.installPlugins[0]"
    value = "configuration-as-code:latest"
  }

  set {
    name  = "controller.installPlugins[1]"
    value = "kubernetes:latest"
  }

  set {
    name  = "controller.installPlugins[2]"
    value = "kubernetes-credentials-provider:latest"
  }

  set {
    name  = "controller.installPlugins[3]"
    value = "job-dsl:latest"
  }

  set {
    name  = "controller.installPlugins[4]"
    value = "workflow-aggregator:latest"
  }

  set {
    name  = "controller.installPlugins[5]"
    value = "git:latest"
  }

  set {
    name  = "controller.installPlugins[6]"
    value = "credentials:latest"
  }

  set {
    name  = "controller.installPlugins[7]"
    value = "credentials-binding:latest"
  }

  set {
    name  = "controller.installPlugins[8]"
    value = "sonar:latest"
  }

  set {
    name  = "controller.installPlugins[9]"
    value = "matrix-auth:latest"
  }

  set {
    name  = "controller.installPlugins[10]"
    value = "docker-workflow:latest"
  }

  set {
    name  = "controller.installPlugins[11]"
    value = "pipeline-utility-steps:latest"
  }

  set {
    name  = "controller.installPlugins[12]"
    value = "timestamper:latest"
  }

  set {
    name  = "controller.installPlugins[13]"
    value = "ansicolor:latest"
  }

  set {
    name  = "controller.installPlugins[14]"
    value = "ws-cleanup:latest"
  }

  set {
    name  = "controller.installPlugins[15]"
    value = "github-branch-source:latest"
  }

  # JCasC inline config
  set {
    name  = "controller.JCasC.defaultConfig"
    value = "true"
    type  = "string"
  }

  set {
    name = "controller.JCasC.configScripts.platform-config"
    value = yamlencode({
      jenkins = {
        systemMessage = "Platform MVP Jenkins — Managed by Terraform + JCasC"
      }
      unclassified = {
        sonarGlobalConfiguration = {
          buildWrapperEnabled = true
          installations = [{
            name          = "SonarQube"
            serverUrl     = "https://sonar.${var.domain_name}"
            credentialsId = "sonarqube-token"
            triggers = {
              skipScmCause      = false
              skipUpstreamCause = false
            }
          }]
        }
      }
      credentials = {
        system = {
          domainCredentials = [{
            credentials = [{
              string = {
                scope       = "GLOBAL"
                id          = "sonarqube-token"
                secret      = "$${sonarqube-token}"
                description = "SonarQube authentication token"
              }
            }]
          }]
        }
      }
    })
  }

  # Mount the SonarQube token secret as env var for JCasC secret resolution
  set {
    name  = "controller.additionalExistingSecrets[0].name"
    value = kubernetes_secret.jenkins_sonarqube.metadata[0].name
  }

  set {
    name  = "controller.additionalExistingSecrets[0].keyName"
    value = "sonarqube-token"
  }

  # Ingress — ALB
  set {
    name  = "controller.ingress.enabled"
    value = "true"
  }

  set {
    name  = "controller.ingress.apiVersion"
    value = "networking.k8s.io/v1"
  }

  set {
    name  = "controller.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = module.route53_acm.certificate_arn
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTPS\": 443}]"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
    type  = "string"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name"
    value = "platform-ingress"
  }

  set {
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"
    value = "/login"
  }

  set {
    name  = "controller.ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "jenkins.${var.domain_name}"
  }

  set {
    name  = "controller.ingress.hostName"
    value = "jenkins.${var.domain_name}"
  }

  # Resources
  set {
    name  = "controller.resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "2"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "3Gi"
  }

  # Scheduling
  set {
    name  = "controller.nodeSelector.role"
    value = "platform-control"
  }

  set {
    name  = "controller.tolerations[0].key"
    value = "platform-control"
  }

  set {
    name  = "controller.tolerations[0].value"
    value = "true"
    type  = "string"
  }

  set {
    name  = "controller.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Persistence — EFS
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClass"
    value = "efs-sc"
  }

  set {
    name  = "persistence.accessMode"
    value = "ReadWriteMany"
  }

  set {
    name  = "persistence.size"
    value = "50Gi"
  }

  # Service account
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "jenkins"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "rbac.readSecrets"
    value = "true"
  }

  # Agent
  set {
    name  = "agent.enabled"
    value = "true"
  }

  set {
    name  = "agent.namespace"
    value = "jenkins"
  }

  depends_on = [
    helm_release.aws_lb_controller,
    helm_release.external_dns,
    helm_release.efs_csi_driver,
    kubernetes_storage_class.efs,
    helm_release.sonarqube,
    helm_release.artifactory_oss,
  ]
}

# ================================================================
# 7. SAMPLE APP (initial deploy)
# ================================================================

resource "helm_release" "sample_app" {
  count = var.deploy_sample_app ? 1 : 0

  name      = "sample-app"
  chart     = "${path.module}/../../../kubernetes/apps/sample-app/chart"
  namespace = kubernetes_namespace.apps.metadata[0].name
  timeout   = 300

  set {
    name  = "image.repository"
    value = module.ecr.repository_urls["sample-app"]
  }

  set {
    name  = "image.tag"
    value = var.sample_app_image_tag
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = module.route53_acm.certificate_arn
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTPS\": 443}]"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name"
    value = "platform-ingress"
  }

  set {
    name  = "ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "app.${var.domain_name}"
  }

  set {
    name  = "ingress.host"
    value = "app.${var.domain_name}"
  }

  set {
    name  = "nodeSelector.role"
    value = "platform-exec"
  }

  depends_on = [
    helm_release.aws_lb_controller,
    helm_release.external_dns,
  ]
}
