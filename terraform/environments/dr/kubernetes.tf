# DR Workspace — kubernetes.tf
#
# The DR workspace uses the SAME kubernetes.tf as the primary (dev) workspace.
#
# RECOMMENDED SETUP: In TFC, configure the DR workspace to use the same
# working directory as dev: "terraform/environments/dev"
#
# This workspace only overrides variable values via TFC workspace variables:
#   aws_region        = "us-west-2"
#   cluster_name      = "platform-mvp-dr"
#   vpc_cidr          = "10.20.0.0/16"
#   ...
#   rds_endpoint_override = ""   # Set to restored RDS endpoint during DR
#
# If you prefer a separate working directory, copy
# terraform/environments/dev/kubernetes.tf to this directory verbatim.
# The file already handles DR correctly:
#   - SonarQube JDBC URL: conditional on var.rds_endpoint_override
#   - Velero: gated on var.enable_velero (default true in DR variables.tf)
#   - All other resources: identical to dev
