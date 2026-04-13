/**
 * Send a notification (placeholder for Slack/Teams/email integration).
 *
 * @param config Map with keys:
 *   - message: Notification message
 *   - channel: Target channel (default: '#builds')
 *   - status: Build status ('SUCCESS', 'FAILURE', 'UNSTABLE')
 *   - color: Message color (optional, derived from status)
 */
def call(Map config = [:]) {
    def message = config.get('message', "Build ${env.JOB_NAME} #${env.BUILD_NUMBER}")
    def channel = config.get('channel', '#builds')
    def status  = config.get('status', currentBuild.currentResult)

    def color = config.get('color', '')
    if (!color) {
        switch (status) {
            case 'SUCCESS':  color = 'good'; break
            case 'FAILURE':  color = 'danger'; break
            case 'UNSTABLE': color = 'warning'; break
            default:         color = '#439FE0'; break
        }
    }

    echo "[NOTIFICATION] ${status}: ${message} (channel: ${channel})"

    // Placeholder: Replace with actual Slack/Teams integration
    // slackSend(channel: channel, color: color, message: message)
}
