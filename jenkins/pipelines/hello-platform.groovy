// Hello Platform — Validates platform connectivity
// Create as a Pipeline job in Jenkins, paste this as the pipeline script

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: platform-check
    image: amazon/aws-cli:2.15.0
    command: ['sleep', '3600']
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
  nodeSelector:
    role: platform-exec
'''
        }
    }

    stages {
        stage('Environment Info') {
            steps {
                container('platform-check') {
                    sh '''
                        echo "=== Platform Connectivity Validation ==="
                        echo "Hostname: $(hostname)"
                        echo "Date: $(date -u)"
                        echo "Node: ${NODE_NAME:-unknown}"
                        echo ""
                    '''
                }
            }
        }

        stage('SonarQube Health') {
            steps {
                container('platform-check') {
                    sh '''
                        echo "=== Checking SonarQube ==="
                        SONAR_STATUS=$(curl -sk https://sonar.manoj-tech-solutions.site/api/system/status)
                        echo "SonarQube API response: ${SONAR_STATUS}"
                        echo "${SONAR_STATUS}" | grep -q '"status":"UP"' && echo "PASS: SonarQube is UP" || (echo "FAIL: SonarQube not healthy"; exit 1)
                    '''
                }
            }
        }

        stage('Artifactory Health') {
            steps {
                container('platform-check') {
                    sh '''
                        echo "=== Checking Artifactory ==="
                        ART_STATUS=$(curl -sk https://artifactory.manoj-tech-solutions.site/artifactory/api/system/ping)
                        echo "Artifactory ping: ${ART_STATUS}"
                        echo "${ART_STATUS}" | grep -q "OK" && echo "PASS: Artifactory is UP" || echo "WARN: Artifactory may not be ready yet"
                    '''
                }
            }
        }

        stage('Jenkins Self-Check') {
            steps {
                container('platform-check') {
                    sh '''
                        echo "=== Checking Jenkins ==="
                        JENKINS_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://jenkins.manoj-tech-solutions.site/login)
                        echo "Jenkins HTTP status: ${JENKINS_STATUS}"
                        [ "${JENKINS_STATUS}" = "200" ] && echo "PASS: Jenkins is UP" || (echo "FAIL: Jenkins not responding"; exit 1)
                    '''
                }
            }
        }

        stage('AWS Connectivity') {
            steps {
                container('platform-check') {
                    sh '''
                        echo "=== Checking AWS Access ==="
                        aws sts get-caller-identity || echo "WARN: No AWS credentials on agent (expected if no IRSA)"
                        echo ""
                        echo "=== All platform checks complete ==="
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'All platform connectivity checks PASSED'
        }
        failure {
            echo 'Some platform checks FAILED — review logs above'
        }
    }
}
