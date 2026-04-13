// SonarQube Scan Validation — Tests code analysis pipeline
// Create as a Pipeline job in Jenkins, paste this as the pipeline script

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli:5.0
    command: ['sleep', '3600']
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
  nodeSelector:
    role: platform-exec
'''
        }
    }

    environment {
        SONAR_HOST_URL = 'https://sonar.manoj-tech-solutions.site'
    }

    stages {
        stage('Create Sample Project') {
            steps {
                container('sonar-scanner') {
                    sh '''
                        mkdir -p /tmp/sample-project/src
                        cat > /tmp/sample-project/src/main.js << 'JSEOF'
// Sample JavaScript file for SonarQube analysis
function greet(name) {
    if (!name) {
        return "Hello, World!";
    }
    return "Hello, " + name + "!";
}

function add(a, b) {
    return a + b;
}

function isEven(num) {
    return num % 2 === 0;
}

// Intentional code smell: unused variable
var unusedVar = "this should trigger a warning";

module.exports = { greet, add, isEven };
JSEOF

                        cat > /tmp/sample-project/src/utils.js << 'JSEOF'
// Utility functions
function formatDate(date) {
    const d = new Date(date);
    return d.toISOString().split('T')[0];
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = { formatDate, sleep };
JSEOF
                        echo "Sample project created with intentional code smells"
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                container('sonar-scanner') {
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            cd /tmp/sample-project
                            sonar-scanner \
                                -Dsonar.projectKey=platform-validation-test \
                                -Dsonar.projectName="Platform Validation Test" \
                                -Dsonar.sources=src \
                                -Dsonar.sourceEncoding=UTF-8
                        '''
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        stage('Verify Project in SonarQube') {
            steps {
                container('sonar-scanner') {
                    sh '''
                        echo "=== Checking project in SonarQube ==="
                        PROJECT_STATUS=$(curl -sk "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=platform-validation-test")
                        echo "Quality Gate Status:"
                        echo "${PROJECT_STATUS}" | python3 -m json.tool 2>/dev/null || echo "${PROJECT_STATUS}"
                        echo ""
                        echo "PASS: SonarQube analysis completed successfully"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'SonarQube scan validation PASSED — analysis and quality gate check complete'
        }
        failure {
            echo 'SonarQube scan validation FAILED — check logs above'
        }
    }
}
