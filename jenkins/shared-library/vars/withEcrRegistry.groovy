/**
 * Wrap a closure with ECR registry authentication.
 *
 * @param config Map with keys:
 *   - registry: ECR registry URL
 *   - region: AWS region (default: us-east-1)
 * @param body Closure to execute with registry auth
 */
def call(Map config = [:], Closure body) {
    def registry = config.get('registry', env.ECR_REGISTRY)
    def region   = config.get('region', env.AWS_REGION ?: 'us-east-1')

    sh "aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${registry}"

    try {
        body()
    } finally {
        sh "docker logout ${registry} || true"
    }
}
