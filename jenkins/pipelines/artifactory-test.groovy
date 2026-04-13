// Artifactory Validation — Tests artifact upload/download round-trip
// Create as a Pipeline job in Jenkins, paste this as the pipeline script

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: artifact-test
    image: alpine:3.19
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

    environment {
        ARTIFACTORY_URL = 'https://artifactory.manoj-tech-solutions.site/artifactory'
        // Default admin credentials for fresh JFrog OSS install
        ARTIFACTORY_USER = 'admin'
        ARTIFACTORY_PASS = 'password'
    }

    stages {
        stage('Setup') {
            steps {
                container('artifact-test') {
                    sh 'apk add --no-cache curl jq'
                }
            }
        }

        stage('Artifactory Health Check') {
            steps {
                container('artifact-test') {
                    sh '''
                        echo "=== Checking Artifactory Health ==="
                        curl -sk ${ARTIFACTORY_URL}/api/system/ping
                        echo ""
                        curl -sku ${ARTIFACTORY_USER}:${ARTIFACTORY_PASS} ${ARTIFACTORY_URL}/api/system/version | jq .
                    '''
                }
            }
        }

        stage('Create Test Repository') {
            steps {
                container('artifact-test') {
                    sh '''
                        echo "=== Creating generic-local test repo ==="
                        curl -sku ${ARTIFACTORY_USER}:${ARTIFACTORY_PASS} \
                            -X PUT "${ARTIFACTORY_URL}/api/repositories/test-generic-local" \
                            -H "Content-Type: application/json" \
                            -d '{"key":"test-generic-local","rclass":"local","packageType":"generic","description":"Test repo for validation"}'
                        echo ""
                    '''
                }
            }
        }

        stage('Upload Artifact') {
            steps {
                container('artifact-test') {
                    sh '''
                        echo "=== Uploading test artifact ==="
                        echo "Hello from Platform MVP - Build #${BUILD_NUMBER} - $(date -u)" > /tmp/test-artifact.txt
                        md5sum /tmp/test-artifact.txt

                        curl -sku ${ARTIFACTORY_USER}:${ARTIFACTORY_PASS} \
                            -X PUT "${ARTIFACTORY_URL}/test-generic-local/validation/test-artifact-${BUILD_NUMBER}.txt" \
                            -T /tmp/test-artifact.txt
                        echo ""
                        echo "Upload complete"
                    '''
                }
            }
        }

        stage('Download & Verify Artifact') {
            steps {
                container('artifact-test') {
                    sh '''
                        echo "=== Downloading artifact back ==="
                        curl -sku ${ARTIFACTORY_USER}:${ARTIFACTORY_PASS} \
                            -o /tmp/downloaded-artifact.txt \
                            "${ARTIFACTORY_URL}/test-generic-local/validation/test-artifact-${BUILD_NUMBER}.txt"

                        echo "Downloaded content:"
                        cat /tmp/downloaded-artifact.txt

                        echo ""
                        echo "=== Comparing checksums ==="
                        ORIG_MD5=$(md5sum /tmp/test-artifact.txt | awk '{print $1}')
                        DOWN_MD5=$(md5sum /tmp/downloaded-artifact.txt | awk '{print $1}')

                        echo "Original: ${ORIG_MD5}"
                        echo "Downloaded: ${DOWN_MD5}"

                        if [ "${ORIG_MD5}" = "${DOWN_MD5}" ]; then
                            echo "PASS: Artifact round-trip successful — checksums match"
                        else
                            echo "FAIL: Checksums do not match"
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('List Artifacts') {
            steps {
                container('artifact-test') {
                    sh '''
                        echo "=== Listing repo contents ==="
                        curl -sku ${ARTIFACTORY_USER}:${ARTIFACTORY_PASS} \
                            "${ARTIFACTORY_URL}/api/storage/test-generic-local/validation/" | jq .
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Artifactory validation PASSED — upload/download round-trip successful'
        }
        failure {
            echo 'Artifactory validation FAILED — check logs above'
        }
    }
}
