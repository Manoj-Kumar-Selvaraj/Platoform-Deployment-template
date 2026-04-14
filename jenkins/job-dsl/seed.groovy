// Seed Job — creates multibranch pipeline for sample-app
// This job is loaded via JCasC or run as an initial seed job

multibranchPipelineJob('sample-app') {
    displayName('Sample App Pipeline')
    description('End-to-end CI/CD pipeline: build, scan, push to ECR, deploy to test namespace')

    branchSources {
        git {
            id('sample-app-git')
            remote('${SAMPLE_APP_REPO_URL}')
            credentialsId('github-credentials')
        }
    }

    orphanedItemStrategy {
        discardOldItems {
            numToKeep(10)
        }
    }

    factory {
        workflowBranchProjectFactory {
            scriptPath('Jenkinsfile')
        }
    }

    triggers {
        periodicFolderTrigger {
            interval('5m')
        }
    }
}

// Seed job for the platform shared library validation
pipelineJob('platform-shared-lib-validation') {
    displayName('Shared Library Validation')
    description('Validates the platform shared library')

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('${SHARED_LIBRARY_REPO}')
                        credentials('github-credentials')
                    }
                    branches('*/main')
                }
            }
            scriptPath('Jenkinsfile')
            lightweight(true)
        }
    }
}

// Manual deploy-to-test job for ad-hoc deployments
pipelineJob('deploy-to-test') {
    displayName('Deploy to Test')
    description('Manually trigger deployment of sample-app to test namespace with a specific image tag')

    parameters {
        stringParam('IMAGE_TAG', 'latest', 'Image tag to deploy (must exist in ECR)')
    }

    definition {
        cps {
            script('''
                @Library('platform-shared-lib') _
                import org.platform.Constants

                pipeline {
                    agent {
                        kubernetes {
                            yamlFile 'jenkins/shared-library/resources/pod-templates/build-agent.yaml'
                        }
                    }
                    stages {
                        stage('Deploy to Test') {
                            steps {
                                container('helm') {
                                    helmDeploy(
                                        releaseName: 'sample-app',
                                        chart: 'kubernetes/apps/sample-app/chart',
                                        namespace: 'test',
                                        valuesFile: 'kubernetes/apps/sample-app/chart/values-test.yaml',
                                        set: [
                                            'image.repository': "${env.ECR_REGISTRY}/sample-app",
                                            'image.tag'       : params.IMAGE_TAG
                                        ]
                                    )
                                }
                            }
                        }
                        stage('Smoke Test') {
                            steps {
                                sh """
                                    for i in \\$(seq 1 10); do
                                        if curl -sf https://test-app.${Constants.DOMAIN}/health; then
                                            echo "\\nSmoke test passed"
                                            exit 0
                                        fi
                                        echo "Attempt \\$i/10, retrying..."
                                        sleep 10
                                    done
                                    echo "Smoke test failed"
                                    exit 1
                                """
                            }
                        }
                    }
                }
            '''.stripIndent())
            sandbox(true)
        }
    }
}
