# -----------------------------------------------------
# CodeArtifact Domain
# -----------------------------------------------------
resource "aws_codeartifact_domain" "main" {
  count  = var.enabled ? 1 : 0
  domain = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.project_name}-codeartifact-domain"
  })
}

# -----------------------------------------------------
# CodeArtifact Internal Repository
# -----------------------------------------------------
resource "aws_codeartifact_repository" "internal" {
  count = var.enabled ? 1 : 0

  repository = "${var.project_name}-internal"
  domain     = aws_codeartifact_domain.main[0].domain

  upstream {
    repository_name = aws_codeartifact_repository.upstream[0].repository
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-internal-repo"
  })
}

# -----------------------------------------------------
# CodeArtifact Upstream Repository (external connection)
# -----------------------------------------------------
resource "aws_codeartifact_repository" "upstream" {
  count = var.enabled ? 1 : 0

  repository = "${var.project_name}-upstream"
  domain     = aws_codeartifact_domain.main[0].domain

  external_connections {
    external_connection_name = var.external_connection
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-upstream-repo"
  })
}
