// first attempte at the pipeline
pipeline {
    agent any

    environment {
        REGISTRY = 'docker.io'
        REPO = 'vishyswaminathan/nodeapp'
        IMAGE_TAG = "v${env.BUILD_NUMBER}"
        SONAR_PROJECT_KEY = 'nodeapp'
        SONAR_HOST_URL = 'https://81f2-142-181-192-68.ngrok-free.app'
        SONAR_TOKEN = credentials('sonar')
        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        HELM_REPO_URL = 'git@github.com:vishyswaminathan/helm-manifest-nodeapp.git'
        HELM_REPO_DIR = 'helm-manifest-nodeapp'
    }

    stages {
        stage('Clone App Repo') {
            steps {
                git url: 'git@github.com:vishyswaminathan/node-app-code.git'
            }
        }

        stage('Run Unit Tests') {
            steps {
                sh 'npm install && npm test'
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('MySonarQubeServer') {
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

        stage('Build Docker Image') {
            steps {
                sh "docker build -t $REPO:$IMAGE_TAG ."
            }
        }

        stage('Trivy Scan') {
            steps {
                sh """
                    trivy image $REPO:$IMAGE_TAG || true
                """
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
                sh """
                    docker rmi $REPO:$IMAGE_TAG || echo 'Image not found, skipping cleanup'
                """
            }
        }

        stage('Clone Helm Manifest Repo') {
            steps {
                dir("$HELM_REPO_DIR") {
                    git url: "$HELM_REPO_URL", branch: 'main', credentialsId: 'github'
                }
            }
        }

        stage('Update Helm values.yaml') {
            steps {
                dir("$HELM_REPO_DIR") {
                    sh """
                        sed -i '' 's|image: .*|image: $REPO:$IMAGE_TAG|' values.yaml
                    """
                }
            }
        }

        stage('Commit and Push to Helm Repo') {
            steps {
                dir("$HELM_REPO_DIR") {
                    sshagent(['your-github-ssh-credential-id']) {
                        sh """
                            git config user.email "ci@yourdomain.com"
                            git config user.name "CI Bot"
                            git add values.yaml
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
            echo "CI/CD pipeline completed successfully. ArgoCD will detect the manifest change and deploy the new version."
        }
        failure {
            echo "CI/CD pipeline failed. Check logs for details."
        }
    }
}
