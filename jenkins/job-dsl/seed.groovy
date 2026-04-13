// Seed Job — creates multibranch pipeline for sample-app
// This job is loaded via JCasC or run as an initial seed job

multibranchPipelineJob('sample-app') {
    displayName('Sample App Pipeline')
    description('Multibranch pipeline for the sample application')

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
