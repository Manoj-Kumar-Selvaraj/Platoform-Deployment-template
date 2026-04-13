/**
 * Trigger Ansible playbook execution on the Ansible runner via AWS SSM.
 *
 * @param config Map with keys:
 *   - instanceId: Ansible runner EC2 instance ID
 *   - playbook: Playbook path on the runner
 *   - inventory: Inventory path on the runner
 *   - extraVars: Map of extra variables (optional)
 *   - region: AWS region (default: us-east-1)
 *   - timeout: SSM command timeout in seconds (default: 600)
 */
def call(Map config = [:]) {
    def instanceId = config.get('instanceId', env.ANSIBLE_RUNNER_ID)
    def playbook   = config.playbook
    def inventory  = config.get('inventory', 'inventories/aws/hosts.yml')
    def extraVars  = config.get('extraVars', [:])
    def region     = config.get('region', env.AWS_REGION ?: 'us-east-1')
    def timeout    = config.get('timeout', 600)

    if (!instanceId || !playbook) {
        error "ansibleTrigger: 'instanceId' and 'playbook' are required"
    }

    def extraVarsStr = ""
    if (extraVars) {
        def pairs = extraVars.collect { k, v -> "${k}=${v}" }.join(' ')
        extraVarsStr = "-e '${pairs}'"
    }

    def command = "cd /opt/ansible && ansible-playbook -i ${inventory} ${playbook} ${extraVarsStr}"

    sh """
        aws ssm send-command \
            --instance-ids '${instanceId}' \
            --document-name 'AWS-RunShellScript' \
            --parameters "commands=['${command}']" \
            --timeout-seconds ${timeout} \
            --region ${region} \
            --output json
    """
}
