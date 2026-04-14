/**
 * Publish a file to JFrog Artifactory via REST API.
 *
 * @param config Map with keys:
 *   - filePath:       Local path of the file to upload (required)
 *   - targetRepo:     Artifactory repository name (default: 'generic-local')
 *   - artifactPath:   Path within the repo, e.g. 'sample-app/42/sample-app-42.tgz' (required)
 *   - artifactoryUrl: Base URL of Artifactory (default: reads ARTIFACTORY_URL env var)
 *   - credentialsId:  Jenkins credentials ID for usernamePassword (default: 'artifactory-credentials')
 */
def call(Map config = [:]) {
    def filePath       = config.filePath
    def targetRepo     = config.get('targetRepo', 'generic-local')
    def artifactPath   = config.artifactPath
    def artifactoryUrl = config.get('artifactoryUrl', env.ARTIFACTORY_URL)
    def credentialsId  = config.get('credentialsId', 'artifactory-credentials')

    if (!filePath || !artifactPath) {
        error "artifactoryPublish: 'filePath' and 'artifactPath' are required"
    }

    if (!artifactoryUrl) {
        error "artifactoryPublish: 'artifactoryUrl' or ARTIFACTORY_URL env var must be set"
    }

    def uploadUrl = "${artifactoryUrl}/artifactory/${targetRepo}/${artifactPath}"

    withCredentials([usernamePassword(
        credentialsId: credentialsId,
        usernameVariable: 'ARTIFACTORY_USER',
        passwordVariable: 'ARTIFACTORY_PASS'
    )]) {
        sh """
            echo "Publishing ${filePath} to ${uploadUrl}"
            curl -f -u \${ARTIFACTORY_USER}:\${ARTIFACTORY_PASS} \
                -T ${filePath} \
                "${uploadUrl}"
            echo "\\nArtifact published successfully: ${uploadUrl}"
        """
    }
}
