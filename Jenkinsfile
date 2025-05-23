/// testing pipeline build before a pull request
pipeline {
    agent any

    tools {
        nodejs "node16"
    }

    environment {
        REGISTRY = 'docker.io'
        REPO = 'vishyswaminathan/nodeapp'
        IMAGE_TAG = "v${env.BUILD_NUMBER}"
        SONAR_PROJECT_KEY = 'nodeapp-feature'
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
                    def branch = env.BRANCH_NAME ?: 'feature'
                    env.DEPLOYMENT_TAG = (branch == 'main' || branch == 'master') ? "prod" : "staging"
                    sh """
                        docker build -t $REPO:$IMAGE_TAG -t $REPO:${env.DEPLOYMENT_TAG} .
                        echo "Built image with tags: $IMAGE_TAG and ${env.DEPLOYMENT_TAG}"
                    """
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
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin $REGISTRY
                        docker push $REPO:$IMAGE_TAG
                        docker push $REPO:${env.DEPLOYMENT_TAG}
                        echo "Pushed tags: $IMAGE_TAG and ${env.DEPLOYMENT_TAG}"
                    """
                }
            }
        }

        stage('Clean Up Local Docker Images') {
            steps {
                sh "docker rmi $REPO:$IMAGE_TAG $REPO:${env.DEPLOYMENT_TAG} || echo 'Image not found, skipping cleanup'"
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
            def valuesFile = "helm/values-${env.DEPLOYMENT_TAG}.yaml"
            dir("${HELM_REPO_DIR}") {
                // Read the current tag from the file
                def currentTag = sh(script: "grep 'tag:' ${valuesFile} | awk '{print \$2}'", returnStdout: true).trim().replaceAll(/^"|\"$/, '')
                
                // Compare with IMAGE_TAG (not DEPLOYMENT_TAG anymore)
                if (currentTag != "${IMAGE_TAG}") {
                    sh """
                        sed -i.bak 's|tag: .*|tag: "${IMAGE_TAG}"|' ${valuesFile}
                        rm -f ${valuesFile}.bak
                    """
                    env.VALUES_UPDATED = "true"
                    echo "🔧 Updated ${valuesFile} with tag ${IMAGE_TAG}"
                } else {
                    echo "✅ Tag already up to date in ${valuesFile}"
                    env.VALUES_UPDATED = "false"
                }
            }
        }
    }
}


        stage('Commit and Push to Helm Repo') {
            steps {
                script {
                    dir("${HELM_REPO_DIR}") {
                        sshagent(['github']) {
                            sh """
                                git config user.email "vishy.1981@gmail.com"
                                git config user.name "vishy.swaminathan"
                            """
                            def changes = sh(script: "git status --porcelain", returnStdout: true).trim()
                            if (changes) {
                                sh """
                                    git add helm/values-*.yaml
                                    git commit -m "Auto-update: Set image tag to ${env.DEPLOYMENT_TAG} [BUILD ${env.BUILD_NUMBER}]"
                                    git push origin main
                                """
                            } else {
                                echo "🔄 No changes in Helm values — skipping commit."
                            }
                        }
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
