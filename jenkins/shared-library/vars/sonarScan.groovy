/**
 * Run SonarQube analysis.
 *
 * @param config Map with keys:
 *   - sonarInstallation: SonarQube installation name (default: 'SonarQube')
 *   - projectKey: SonarQube project key
 *   - projectName: SonarQube project name (default: projectKey)
 *   - sources: Source directory (default: 'src')
 *   - waitForQualityGate: Boolean to wait for QG (default: true)
 *   - timeout: Quality gate timeout in minutes (default: 5)
 */
def call(Map config = [:]) {
    def installation      = config.get('sonarInstallation', 'SonarQube')
    def projectKey        = config.projectKey
    def projectName       = config.get('projectName', projectKey)
    def sources           = config.get('sources', 'src')
    def waitForQG         = config.get('waitForQualityGate', true)
    def timeout           = config.get('timeout', 5)

    if (!projectKey) {
        error "sonarScan: 'projectKey' is required"
    }

    withSonarQubeEnv(installation) {
        sh """
            sonar-scanner \
                -Dsonar.projectKey=${projectKey} \
                -Dsonar.projectName=${projectName} \
                -Dsonar.sources=${sources} \
                -Dsonar.host.url=\${SONAR_HOST_URL} \
                -Dsonar.token=\${SONAR_AUTH_TOKEN}
        """
    }

    if (waitForQG) {
        timeout(time: timeout, unit: 'MINUTES') {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
                error "Quality Gate failed: ${qg.status}"
            }
        }
    }
}
