pipeline {
    agent { label 'docker-slave' }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 35, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        PROJECT_NAME       = ''
        NAMESPACE          = ''
        APP_HOST           = ''
        REPLICAS           = ''
        NEXUS_REGISTRY     = ''
        NEXUS_REPO         = ''
        INGRESS_CLASS      = ''
        SONAR_PROJECT_KEY  = ''
        SONAR_SERVER_NAME  = ''
        TECHNITIUM_API_URL = ''
        TECHNITIUM_ZONE    = ''
        NPM_IP             = ''
        NPM_API_URL        = ''
        NPM_FORWARD_IP     = ''
        NPM_FORWARD_PORT   = ''
        FULL_IMAGE         = ''
        LATEST_IMAGE       = ''
    }

    stages {
        stage('Checkout') {
            steps {
                deleteDir()
                checkout scm

                sh '''
                    set -eux
                    test -f project.env
                    test -f sonar-project.properties
                    test -f Dockerfile
                    test -d app
                    test -d k8s
                    test -d scripts
                    git log -1 --oneline
                '''
            }
        }

        stage('Load config') {
            steps {
                script {
                    // Sandbox-safe: source project.env in the shell and assign each
                    // approved Jenkins environment property explicitly.
                    env.PROJECT_NAME = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$PROJECT_NAME\"",
                        returnStdout: true
                    ).trim()
                    env.NAMESPACE = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NAMESPACE\"",
                        returnStdout: true
                    ).trim()
                    env.APP_HOST = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$APP_HOST\"",
                        returnStdout: true
                    ).trim()
                    env.REPLICAS = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$REPLICAS\"",
                        returnStdout: true
                    ).trim()
                    env.NEXUS_REGISTRY = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NEXUS_REGISTRY\"",
                        returnStdout: true
                    ).trim()
                    env.NEXUS_REPO = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NEXUS_REPO\"",
                        returnStdout: true
                    ).trim()
                    env.INGRESS_CLASS = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$INGRESS_CLASS\"",
                        returnStdout: true
                    ).trim()
                    env.SONAR_PROJECT_KEY = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$SONAR_PROJECT_KEY\"",
                        returnStdout: true
                    ).trim()
                    env.SONAR_SERVER_NAME = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$SONAR_SERVER_NAME\"",
                        returnStdout: true
                    ).trim()
                    env.TECHNITIUM_API_URL = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$TECHNITIUM_API_URL\"",
                        returnStdout: true
                    ).trim()
                    env.TECHNITIUM_ZONE = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$TECHNITIUM_ZONE\"",
                        returnStdout: true
                    ).trim()
                    env.NPM_IP = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NPM_IP\"",
                        returnStdout: true
                    ).trim()
                    env.NPM_API_URL = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NPM_API_URL\"",
                        returnStdout: true
                    ).trim()
                    env.NPM_FORWARD_IP = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NPM_FORWARD_IP\"",
                        returnStdout: true
                    ).trim()
                    env.NPM_FORWARD_PORT = sh(
                        script: "set -a; . ./project.env; printf '%s' \"\$NPM_FORWARD_PORT\"",
                        returnStdout: true
                    ).trim()

                    env.FULL_IMAGE = "${env.NEXUS_REGISTRY}/${env.NEXUS_REPO}:${env.BUILD_NUMBER}"
                    env.LATEST_IMAGE = "${env.NEXUS_REGISTRY}/${env.NEXUS_REPO}:latest"
                }

                sh '''
                    set -eu

                    required_vars="PROJECT_NAME NAMESPACE APP_HOST REPLICAS NEXUS_REGISTRY NEXUS_REPO INGRESS_CLASS SONAR_PROJECT_KEY SONAR_SERVER_NAME TECHNITIUM_API_URL TECHNITIUM_ZONE NPM_IP NPM_API_URL NPM_FORWARD_IP NPM_FORWARD_PORT"

                    for variable_name in ${required_vars}; do
                        eval "variable_value=\${${variable_name}:-}"
                        if [ -z "${variable_value}" ]; then
                            echo "ERROR: Missing required value in project.env: ${variable_name}" >&2
                            exit 1
                        fi
                    done

                    case "${REPLICAS}" in
                        ''|*[!0-9]*)
                            echo "ERROR: REPLICAS must be a positive integer" >&2
                            exit 1
                            ;;
                        0)
                            echo "ERROR: REPLICAS must be greater than zero" >&2
                            exit 1
                            ;;
                    esac

                    echo "Project:   ${PROJECT_NAME}"
                    echo "Namespace: ${NAMESPACE}"
                    echo "Image:     ${FULL_IMAGE}"
                    echo "Hostname:  ${APP_HOST}"
                '''
            }
        }

        stage('Validate agent') {
            steps {
                sh '''
                    set -eux
                    whoami
                    hostname
                    git --version
                    docker version
                    kubectl version --client
                    curl --version | head -1
                    python3 --version
                    sonar-scanner --version
                    docker ps
                '''
            }
        }

        stage('SonarQube analysis') {
            steps {
                withSonarQubeEnv("${SONAR_SERVER_NAME}") {
                    sh '''
                        set -eux
                        sonar-scanner \
                          -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
                          -Dsonar.projectName="${PROJECT_NAME}" \
                          -Dsonar.sources=app \
                          -Dsonar.sourceEncoding=UTF-8
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker build') {
            steps {
                sh '''
                    set -eux
                    docker build \
                      --tag "${FULL_IMAGE}" \
                      --tag "${LATEST_IMAGE}" \
                      .
                    docker image inspect "${FULL_IMAGE}" >/dev/null
                '''
            }
        }

        stage('Container smoke test') {
            steps {
                sh '''
                    set -eux
                    TEST_CONTAINER="${PROJECT_NAME}-smoke-${BUILD_NUMBER}"

                    cleanup() {
                        docker logs "${TEST_CONTAINER}" 2>/dev/null || true
                        docker rm -f "${TEST_CONTAINER}" >/dev/null 2>&1 || true
                    }
                    trap cleanup EXIT

                    docker rm -f "${TEST_CONTAINER}" >/dev/null 2>&1 || true
                    docker run -d \
                      --name "${TEST_CONTAINER}" \
                      -p 127.0.0.1::80 \
                      "${FULL_IMAGE}"

                    TEST_PORT="$(docker port "${TEST_CONTAINER}" 80/tcp | awk -F: '{print $NF}')"

                    curl --fail --retry 15 --retry-delay 2 \
                      "http://127.0.0.1:${TEST_PORT}/healthz"
                    curl --fail --retry 5 --retry-delay 2 \
                      "http://127.0.0.1:${TEST_PORT}/" >/dev/null
                '''
            }
        }

        stage('Push to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -eu
                        set +x
                        printf '%s' "${NEXUS_PASS}" | docker login \
                          "${NEXUS_REGISTRY}" \
                          --username "${NEXUS_USER}" \
                          --password-stdin
                        set -x

                        docker push "${FULL_IMAGE}"
                        docker push "${LATEST_IMAGE}"
                    '''
                }
            }
        }

        stage('Render Kubernetes manifests') {
            steps {
                sh '''
                    set -eux
                    chmod +x scripts/*.sh
                    scripts/render-manifests.sh
                    grep -R "image:" rendered-k8s
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-lab',
                        variable: 'KUBECONFIG_FILE'
                    ),
                    usernamePassword(
                        credentialsId: 'nexus-credentials',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )
                ]) {
                    sh '''
                        set -eu
                        export KUBECONFIG="${KUBECONFIG_FILE}"

                        kubectl cluster-info
                        kubectl create namespace "${NAMESPACE}" \
                          --dry-run=client -o yaml | kubectl apply -f -

                        set +x
                        kubectl create secret docker-registry nexus-regcred \
                          --namespace "${NAMESPACE}" \
                          --docker-server="${NEXUS_REGISTRY}" \
                          --docker-username="${NEXUS_USER}" \
                          --docker-password="${NEXUS_PASS}" \
                          --dry-run=client -o yaml | kubectl apply -f -
                        set -x

                        kubectl apply -f rendered-k8s/
                        kubectl rollout status \
                          "deployment/${PROJECT_NAME}" \
                          --namespace "${NAMESPACE}" \
                          --timeout=300s
                    '''
                }
            }
        }

        stage('Configure Technitium DNS') {
            steps {
                withCredentials([string(
                    credentialsId: 'technitium-api-token',
                    variable: 'TECHNITIUM_API_TOKEN'
                )]) {
                    sh 'scripts/configure-technitium.sh'
                }
            }
        }

        stage('Configure Nginx Proxy Manager') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'npm-creds',
                    usernameVariable: 'NPM_USERNAME',
                    passwordVariable: 'NPM_PASSWORD'
                )]) {
                    sh 'scripts/configure-npm.sh'
                }
            }
        }

        stage('End-to-end test') {
            steps {
                sh '''
                    set -eux

                    # Directly test NPM while forcing the application hostname.
                    curl --fail --retry 20 --retry-delay 3 \
                      --resolve "${APP_HOST}:80:${NPM_IP}" \
                      "http://${APP_HOST}/healthz"

                    # Confirm ordinary DNS resolution also works.
                    getent hosts "${APP_HOST}"
                    curl --fail --retry 10 --retry-delay 3 \
                      "http://${APP_HOST}/" >/dev/null
                '''
            }
        }
    }

    post {
        unsuccessful {
            script {
                if (env.NAMESPACE?.trim() && env.PROJECT_NAME?.trim()) {
                    withCredentials([file(
                        credentialsId: 'kubeconfig-lab',
                        variable: 'KUBECONFIG_FILE'
                    )]) {
                        sh '''
                            set +e
                            export KUBECONFIG="${KUBECONFIG_FILE}"

                            kubectl get all,ingress \
                              -n "${NAMESPACE}" -o wide || true

                            kubectl get events \
                              -n "${NAMESPACE}" \
                              --sort-by=.lastTimestamp | tail -40 || true

                            kubectl describe deployment "${PROJECT_NAME}" \
                              -n "${NAMESPACE}" || true

                            exit 0
                        '''
                    }
                } else {
                    echo 'Kubernetes diagnostics skipped because project.env was not loaded.'
                }
            }
        }

        success {
            echo "TheMaximus build ${BUILD_NUMBER} deployed: http://${APP_HOST}"
        }

        failure {
            echo "Pipeline failed at build ${BUILD_NUMBER}. Check the first failed stage."
        }

        always {
            sh '''
                set +e
                docker logout "${NEXUS_REGISTRY}" >/dev/null 2>&1 || true
                docker rm -f "${PROJECT_NAME}-smoke-${BUILD_NUMBER}" \
                  >/dev/null 2>&1 || true
                exit 0
            '''

            archiveArtifacts artifacts: 'rendered-k8s/*.yaml',
                allowEmptyArchive: true,
                fingerprint: true
        }
    }
}
