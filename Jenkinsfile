@Library('platform-shared-lib') _

import org.platform.Constants

pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins/shared-library/resources/pod-templates/build-agent.yaml'
        }
    }

    environment {
        APP_NAME    = 'sample-app'
        SRC_DIR     = 'kubernetes/apps/sample-app/src'
        CHART_PATH  = 'kubernetes/apps/sample-app/chart'
        DEPLOY_NS   = 'test'
        IMAGE_TAG   = "${BUILD_NUMBER}"
        DOMAIN      = Constants.DOMAIN
        TEST_HOST   = "test-app.${Constants.DOMAIN}"
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                container('jnlp') {
                    dir(env.SRC_DIR) {
                        sh 'npm ci'
                    }
                }
            }
        }

        stage('Code Quality - SonarQube') {
            steps {
                sonarScan(
                    projectKey: env.APP_NAME,
                    sources: env.SRC_DIR,
                    waitForQualityGate: false
                )
            }
        }

        stage('Build Docker Image') {
            steps {
                container('docker') {
                    buildDocker(
                        context: env.SRC_DIR,
                        imageName: env.APP_NAME,
                        tag: env.IMAGE_TAG
                    )
                }
            }
        }

        stage('Push to ECR') {
            steps {
                container('docker') {
                    ecrPush(
                        imageName: env.APP_NAME,
                        tag: env.IMAGE_TAG
                    )
                }
            }
        }

        stage('Deploy to Test') {
            steps {
                container('helm') {
                    helmDeploy(
                        releaseName: env.APP_NAME,
                        chart: env.CHART_PATH,
                        namespace: env.DEPLOY_NS,
                        valuesFile: "${env.CHART_PATH}/values-test.yaml",
                        set: [
                            'image.repository': "${env.ECR_REGISTRY}/${env.APP_NAME}",
                            'image.tag'       : env.IMAGE_TAG
                        ]
                    )
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh """
                    echo "Waiting for deployment rollout..."
                    RETRIES=10
                    DELAY=10
                    for i in \$(seq 1 \$RETRIES); do
                        if curl -sf https://${env.TEST_HOST}/health; then
                            echo "\\nSmoke test passed on attempt \$i"
                            exit 0
                        fi
                        echo "Attempt \$i/\$RETRIES failed, retrying in \${DELAY}s..."
                        sleep \$DELAY
                    done
                    echo "Smoke test failed after \$RETRIES attempts"
                    exit 1
                """
            }
        }
    }

    post {
        success {
            notifySlack(status: 'SUCCESS', message: "Deployed ${APP_NAME}:${IMAGE_TAG} to test")
        }
        failure {
            notifySlack(status: 'FAILURE', message: "Failed to deploy ${APP_NAME}:${IMAGE_TAG}")
        }
        always {
            cleanWs()
        }
    }
}
