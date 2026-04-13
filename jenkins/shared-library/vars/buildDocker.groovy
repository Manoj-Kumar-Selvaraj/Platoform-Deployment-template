/**
 * Build a Docker image.
 *
 * @param config Map with keys:
 *   - context: Build context path (default: '.')
 *   - dockerfile: Dockerfile path (default: 'Dockerfile')
 *   - imageName: Full image name including registry
 *   - tag: Image tag (default: BUILD_NUMBER)
 */
def call(Map config = [:]) {
    def context    = config.get('context', '.')
    def dockerfile = config.get('dockerfile', 'Dockerfile')
    def imageName  = config.imageName
    def tag        = config.get('tag', env.BUILD_NUMBER)

    if (!imageName) {
        error "buildDocker: 'imageName' is required"
    }

    sh """
        docker build \
            -t ${imageName}:${tag} \
            -t ${imageName}:latest \
            -f ${dockerfile} \
            ${context}
    """

    return "${imageName}:${tag}"
}
