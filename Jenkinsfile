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

        stage('Build Docker Image') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    def secondaryTag = "dev" // Default tag
                    
                    if (branchName == 'master') {
                        secondaryTag = "prod" // Push as `prod` in production
                    } else if (branchName == 'staging' || branchName.startsWith('release/')) {
                        secondaryTag = "staging"
                    }
                    
                    sh 'ls -la'  // Debug: Verify Dockerfile exists
                    sh "docker build -t $REPO:$IMAGE_TAG -t $REPO:${secondaryTag} ."
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                sh "trivy image $REPO:$IMAGE_TAG || true"
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    def secondaryTag = "dev"
                    
                    if (branchName == 'master') {
                        secondaryTag = "prod" // Push `prod` tag to Docker Hub
                    } else if (branchName == 'staging' || branchName.startsWith('release/')) {
                        secondaryTag = "staging"
                    }
                    
                    withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin $REGISTRY
                            docker push $REPO:$IMAGE_TAG
                            docker push $REPO:${secondaryTag}  # Pushes `prod` if on master
                        """
                    }
                }
            }
        }

        stage('Clean Up Local Docker Images') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    def secondaryTag = "dev"
                    
                    if (branchName == 'master') {
                        secondaryTag = "prod"
                    } else if (branchName == 'staging' || branchName.startsWith('release/')) {
                        secondaryTag = "staging"
                    }
                    
                    sh "docker rmi $REPO:$IMAGE_TAG $REPO:${secondaryTag} || echo 'Image not found, skipping cleanup'"
                }
            }
        }

        stage('Clone Helm Manifest Repo') {
            steps {
                dir("${HELM_REPO_DIR}") {
                    git url: "${HELM_REPO_URL}", branch: 'main', credentialsId: 'github'
                }
            }
        }

        stage('Update Helm Values') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    def valuesFile = "helm/values-dev.yaml"
                    def imageTagToUse = IMAGE_TAG  // Default: Use build number (vXX)

                    if (branchName == 'master') {
                        valuesFile = "helm/values-prod.yaml"
                        imageTagToUse = "prod"  // Use "prod" tag in production
                    } else if (branchName == 'staging' || branchName.startsWith('release/')) {
                        valuesFile = "helm/values-staging.yaml"
                        imageTagToUse = "staging"
                    }

                    dir("${HELM_REPO_DIR}") {
                        sh """
                            sed -i.bak 's|tag: .*|tag: \"${imageTagToUse}\"|' ${valuesFile}
                            rm -f ${valuesFile}.bak
                        """
                        env.VALUES_UPDATED = "true"
                    }
                }
            }
        }

        stage('Commit and Push to Helm Repo') {
            when {
                expression { return env.VALUES_UPDATED == "true" }
            }
            steps {
                dir("${HELM_REPO_DIR}") {
                    sshagent(['github']) {
                        sh """
                            git config user.email "vishy.1981@gmail.com"
                            git config user.name "vishy.swaminathan"
                            git add helm/values-*.yaml
                            git commit -m "Auto-update: Set image tag to ${imageTagToUse} [BUILD ${env.BUILD_NUMBER}]"
                            git push origin main
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ CI/CD pipeline completed successfully. ArgoCD will sync the new image version."
        }
        failure {
            echo "❌ CI/CD pipeline failed. Check logs for details."
        }
    }
}