//updating  master branch to test argoCD deployment
pipeline {
    agent any

    tools {
        nodejs "node16"
    }

    environment {
        REGISTRY = 'docker.io'
        REPO = 'vishyswaminathan/nodeapp'
        IMAGE_TAG = "v${env.BUILD_NUMBER}"
        SONAR_PROJECT_KEY = 'nodeapp'
        SONAR_HOST_URL = 'https://c09b-142-181-192-68.ngrok-free.app'
        SONAR_TOKEN = credentials('sonar')
        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        HELM_REPO_URL = 'git@github.com:vishyswaminathan/helm-manifest-nodeapp.git'
        HELM_REPO_DIR = 'helm-manifest-nodeapp'
        APP_DIR = 'node'
    }

    stages {
        stage('Run Unit Tests') {
            steps {
                dir("${APP_DIR}") {
                    sh 'npm install'
                }
            }
        }

        stage('SonarQube Scan') {
            steps {
                dir("${APP_DIR}") {
                    withSonarQubeEnv('sonar') {
                        withEnv(["PATH+SONAR=/usr/local/bin"]) {
                            sh """
                                sonar-scanner \
                                -Dsonar.projectKey=$SONAR_PROJECT_KEY \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=$SONAR_HOST_URL \
                                -Dsonar.login=$SONAR_TOKEN
                            """
                        }
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t $REPO:$IMAGE_TAG -f Dockerfile ."
            }
        }

        stage('Trivy Scan') {
            steps {
                sh "trivy image $REPO:$IMAGE_TAG || true"
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin $REGISTRY
                        docker push $REPO:$IMAGE_TAG
                    """
                }
            }
        }

        stage('Clean Up Local Docker Images') {
            steps {
                sh "docker rmi $REPO:$IMAGE_TAG || echo 'Image not found, skipping cleanup'"
            }
        }

        stage('Clone Helm Manifest Repo') {
            steps {
                dir("${HELM_REPO_DIR}") {
                    git url: "${HELM_REPO_URL}", branch: 'main', credentialsId: 'github'
                }
            }
        }

        stage('Update Helm values file') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: sh(returnStdout: true, script: "git rev-parse --abbrev-ref HEAD").trim()
                    def valuesFile = ""

                    if (branchName == "dev") {
                        valuesFile = "helm/values-dev.yaml"
                    } else if (branchName == "master") {
                        valuesFile = "helm/values-prod.yaml"
                    } else {
                        valuesFile = "helm/values-staging.yaml"
                    }

                    dir("${HELM_REPO_DIR}") {
                        sh """
                            sed -i '' 's|image: .*|image: $REPO:$IMAGE_TAG|' $valuesFile
                        """
                    }
                }
            }
        }

        stage('Commit and Push to Helm Repo') {
            steps {
                dir("${HELM_REPO_DIR}") {
                    sshagent(['github']) {
                        sh """
                            git config user.email "vishy.1981@gmail.com"
                            git config user.name "vishy.swaminathan"
                            git add helm/values-*.yaml
                            git commit -m "Update image to $IMAGE_TAG"
                            git push origin main
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ CI/CD pipeline completed successfully. ArgoCD will pick up the updated values file and deploy the new version."
        }
        failure {
            echo "❌ CI/CD pipeline failed. Check the logs for errors."
        }
    }
}
