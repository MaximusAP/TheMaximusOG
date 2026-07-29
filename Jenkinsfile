pipeline {
    agent { label 'docker-slave' }

    environment {
        PATH+SONAR = '/opt/sonar-scanner/bin'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 35, unit: 'MINUTES')
        skipDefaultCheckout(true)
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
                    // Load project.env once. The variables are returned in a fixed
                    // order and then assigned explicitly to Jenkins env properties.
                    // This avoids dynamic env[key] assignment and Script Approval.
                    def configOutput = sh(
                        script: '''
                            set -eu
                            set -a
                            . ./project.env
                            set +a

                            printf '%s\n' \
                              "${PROJECT_NAME}" \
                              "${NAMESPACE}" \
                              "${APP_HOST}" \
                              "${REPLICAS}" \
                              "${NEXUS_REGISTRY}" \
                              "${NEXUS_REPO}" \
                              "${INGRESS_CLASS}" \
                              "${KUBE_INGRESS_IP}" \
                              "${SONAR_PROJECT_KEY}" \
                              "${SONAR_SERVER_NAME}" \
                              "${TECHNITIUM_API_URL}" \
                              "${TECHNITIUM_ZONE}" \
                              "${NPM_IP}" \
                              "${NPM_API_URL}" \
                              "${NPM_FORWARD_IP}" \
                              "${NPM_FORWARD_PORT}"
                        ''',
                        returnStdout: true
                    ).trim()

                    def values = configOutput.readLines()
                    if (values.size() != 16) {
                        error("Unable to parse project.env: expected 16 values, received ${values.size()}")
                    }

                    env.PROJECT_NAME       = values[0].trim()
                    env.NAMESPACE          = values[1].trim()
                    env.APP_HOST           = values[2].trim()
                    env.REPLICAS           = values[3].trim()
                    env.NEXUS_REGISTRY     = values[4].trim()
                    env.NEXUS_REPO         = values[5].trim()
                    env.INGRESS_CLASS      = values[6].trim()
                    env.KUBE_INGRESS_IP    = values[7].trim()
                    env.SONAR_PROJECT_KEY  = values[8].trim()
                    env.SONAR_SERVER_NAME  = values[9].trim()
                    env.TECHNITIUM_API_URL = values[10].trim()
                    env.TECHNITIUM_ZONE    = values[11].trim()
                    env.NPM_IP             = values[12].trim()
                    env.NPM_API_URL        = values[13].trim()
                    env.NPM_FORWARD_IP     = values[14].trim()
                    env.NPM_FORWARD_PORT   = values[15].trim()

                    if (!env.PROJECT_NAME)       { error('Missing required value in project.env: PROJECT_NAME') }
                    if (!env.NAMESPACE)          { error('Missing required value in project.env: NAMESPACE') }
                    if (!env.APP_HOST)           { error('Missing required value in project.env: APP_HOST') }
                    if (!env.REPLICAS)           { error('Missing required value in project.env: REPLICAS') }
                    if (!env.NEXUS_REGISTRY)     { error('Missing required value in project.env: NEXUS_REGISTRY') }
                    if (!env.NEXUS_REPO)         { error('Missing required value in project.env: NEXUS_REPO') }
                    if (!env.INGRESS_CLASS)      { error('Missing required value in project.env: INGRESS_CLASS') }
                    if (!env.KUBE_INGRESS_IP)    { error('Missing required value in project.env: KUBE_INGRESS_IP') }
                    if (!env.SONAR_PROJECT_KEY)  { error('Missing required value in project.env: SONAR_PROJECT_KEY') }
                    if (!env.SONAR_SERVER_NAME)  { error('Missing required value in project.env: SONAR_SERVER_NAME') }
                    if (!env.TECHNITIUM_API_URL) { error('Missing required value in project.env: TECHNITIUM_API_URL') }
                    if (!env.TECHNITIUM_ZONE)    { error('Missing required value in project.env: TECHNITIUM_ZONE') }
                    if (!env.NPM_IP)             { error('Missing required value in project.env: NPM_IP') }
                    if (!env.NPM_API_URL)        { error('Missing required value in project.env: NPM_API_URL') }
                    if (!env.NPM_FORWARD_IP)     { error('Missing required value in project.env: NPM_FORWARD_IP') }
                    if (!env.NPM_FORWARD_PORT)   { error('Missing required value in project.env: NPM_FORWARD_PORT') }

                    if (!(env.REPLICAS ==~ /[1-9][0-9]*/)) {
                        error('REPLICAS must be a positive integer greater than zero')
                    }

                    env.FULL_IMAGE = "${env.NEXUS_REGISTRY}/${env.NEXUS_REPO}:${env.BUILD_NUMBER}"
                    env.LATEST_IMAGE = "${env.NEXUS_REGISTRY}/${env.NEXUS_REPO}:latest"

                    echo "Project:   ${env.PROJECT_NAME}"
                    echo "Namespace: ${env.NAMESPACE}"
                    echo "Image:     ${env.FULL_IMAGE}"
                    echo "Hostname:  ${env.APP_HOST}"
                }
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
                    echo "PATH=$PATH"
                    echo "Checking SonarScanner installation..."
                    ls -l /opt/sonar-scanner/bin/sonar-scanner
                    command -v sonar-scanner
                    /opt/sonar-scanner/bin/sonar-scanner --version
                    docker ps
                '''
            }
        }

        stage('SonarQube analysis') {
            steps {
                withSonarQubeEnv("${SONAR_SERVER_NAME}") {
                    sh '''
                        set -eux
                        /opt/sonar-scanner/bin/sonar-scanner \
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
