/**
 * Push Docker image to Amazon ECR.
 *
 * @param config Map with keys:
 *   - registry: ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com)
 *   - imageName: Full image name
 *   - tag: Image tag
 *   - region: AWS region (default: us-east-1)
 */
def call(Map config = [:]) {
    def registry  = config.get('registry', env.ECR_REGISTRY)
    def imageName = config.imageName
    def tag       = config.get('tag', env.BUILD_NUMBER)
    def region    = config.get('region', env.AWS_REGION ?: 'us-east-1')

    if (!registry || !imageName) {
        error "ecrPush: 'registry' and 'imageName' are required"
    }

    sh """
        aws ecr get-login-password --region ${region} | \
            docker login --username AWS --password-stdin ${registry}

        docker tag ${imageName}:${tag} ${registry}/${imageName}:${tag}
        docker tag ${imageName}:${tag} ${registry}/${imageName}:latest

        docker push ${registry}/${imageName}:${tag}
        docker push ${registry}/${imageName}:latest
    """
}
