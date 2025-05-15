pipeline {
    agent any

    environment {
        IMAGE_REPO = 'vishyswaminathan/python-image'
        IMAGE_TAG = "v${BUILD_NUMBER}"
        IMAGE_NAME = "${IMAGE_REPO}:${IMAGE_TAG}"
        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        GIT_CREDENTIALS_ID = 'github-credentials-id'
        HELM_REPO_URL = 'git@github.com:youruser/helm-manifest-repo.git'
        APP_REPO_URL = 'git@github.com:youruser/app-repo.git'
        HELM_REPO_DIR = '/opt/helm-manifest'
        APP_REPO_DIR = '/opt/app-code'
    }

    stages {
        stage('Clone App Repo') {
            steps {
                sh """
                    rm -rf ${APP_REPO_DIR}
                    git clone ${APP_REPO_URL} ${APP_REPO_DIR}
                    chown -R jenkins:jenkins ${APP_REPO_DIR}
                """
            }
        }

        stage('Run Unit Tests') {
            steps {
                dir("${APP_REPO_DIR}") {
                    sh 'python3 -m unittest discover'
                }
            }
        }

        stage('Run SonarQube Scan') {
            environment {
                scannerHome = tool 'sonar6.2'
            }
            steps {
                dir("${APP_REPO_DIR}") {
                    withSonarQubeEnv('sonarserver') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=pythonapp \
                            -Dsonar.projectName=PythonApp \
                            -Dsonar.sources=. \
                            -Dsonar.sourceEncoding=UTF-8
                        """
                    }

                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                dir("${APP_REPO_DIR}") {
                    script {
                        docker.build("${IMAGE_NAME}")
                        withCredentials([usernamePassword(credentialsId: DOCKER_CREDENTIALS_ID, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASSWORD')]) {
                            docker.withRegistry('https://index.docker.io/v1/', DOCKER_CREDENTIALS_ID) {
                                docker.image("${IMAGE_NAME}").push()
                            }
                        }
                    }
                }
            }
        }

        stage('Trivy Vulnerability Scan') {
            steps {
                sh """
                    if ! command -v trivy > /dev/null; then
                        echo "Installing Trivy..."
                        apt-get update && apt-get install wget -y
                        wget -q https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.61.1_Linux-64bit.deb -O trivy.deb
                        dpkg -i trivy.deb && rm trivy.deb
                    fi
                    trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed ${IMAGE_NAME}
                """
            }
        }

        stage('Clone Helm Manifest Repo') {
            steps {
                sh """
                    rm -rf ${HELM_REPO_DIR}
                    git clone ${HELM_REPO_URL} ${HELM_REPO_DIR}
                    chown -R jenkins:jenkins ${HELM_REPO_DIR}
                """
            }
        }

        stage('Update values.yaml with New Image Tag') {
            steps {
                dir("${HELM_REPO_DIR}") {
                    script {
                        sh """
                            sed -i 's|image: .*|image: "${IMAGE_REPO}"|' values.yaml
                            sed -i 's|tag: .*|tag: "${IMAGE_TAG}"|' values.yaml
                        """
                    }
                }
            }
        }

        stage('Commit and Push to Trigger ArgoCD') {
            steps {
                dir("${HELM_REPO_DIR}") {
                    withCredentials([sshUserPrivateKey(credentialsId: GIT_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY')]) {
                        sh """
                            git config user.email "jenkins@ci"
                            git config user.name "Jenkins"
                            git add values.yaml
                            git commit -m "Update image tag to ${IMAGE_TAG}"
                            git push origin main
                        """
                    }
                }
            }
        }

        stage('Cleanup Docker Image') {
            steps {
                sh """
                    docker rmi ${IMAGE_NAME} || true
                """
            }
        }
    }

    post {
        success {
            echo "✅ CI/CD Pipeline completed successfully."
        }
        failure {
            echo "❌ Pipeline failed. Check logs for errors."
        }
    }
}
