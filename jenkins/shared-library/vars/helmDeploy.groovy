/**
 * Deploy or upgrade a Helm release.
 *
 * @param config Map with keys:
 *   - releaseName: Helm release name
 *   - chart: Chart path or repo/chart
 *   - namespace: Kubernetes namespace
 *   - valuesFile: Path to values file (optional)
 *   - set: Map of --set overrides (optional)
 *   - wait: Wait for rollout (default: true)
 *   - timeout: Timeout string (default: '5m')
 */
def call(Map config = [:]) {
    def releaseName = config.releaseName
    def chart       = config.chart
    def namespace   = config.get('namespace', 'apps')
    def valuesFile  = config.get('valuesFile', '')
    def setValues   = config.get('set', [:])
    def wait        = config.get('wait', true)
    def timeout     = config.get('timeout', '5m')

    if (!releaseName || !chart) {
        error "helmDeploy: 'releaseName' and 'chart' are required"
    }

    def cmd = "helm upgrade --install ${releaseName} ${chart} --namespace ${namespace} --create-namespace"

    if (valuesFile) {
        cmd += " -f ${valuesFile}"
    }

    setValues.each { key, value ->
        cmd += " --set ${key}=${value}"
    }

    if (wait) {
        cmd += " --wait --timeout ${timeout}"
    }

    sh cmd
}
