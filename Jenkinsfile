// testing pull request
pipeline {
    agent any

    tools {
        nodejs "node16"
    }

    environment {
        REGISTRY = 'docker.io'
        REPO = 'vishyswaminathan/nodeapp'
        SLACK_CHANNEL = '#jenkins'
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


///stage('Force Failure for Testing') {
   /// steps {
      ///  error('Intentional failure to test Slack notification.')
    //}
///}

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
                    env.DEPLOYMENT_TAG = "prod"
                    sh """
                        docker build -t $REPO:$IMAGE_TAG -t $REPO:${env.DEPLOYMENT_TAG} .
                        docker images | grep nodeapp
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
                    def valuesFile = "helm/values-prod.yaml"
                    def targetTag = "prod"
                    
                    dir("${HELM_REPO_DIR}") {
                        def currentTag = sh(script: "grep 'tag:' ${valuesFile} | awk '{print \$2}'", returnStdout: true).trim()
                        
                        if (currentTag != "\"${targetTag}\"") {
                            sh """
                                sed -i.bak 's|tag: .*|tag: \"${targetTag}\"|' ${valuesFile}
                                rm -f ${valuesFile}.bak
                            """
                            env.VALUES_UPDATED = "true"
                        } else {
                            echo "Tag in ${valuesFile} already matches ${targetTag}"
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
                                git add helm/values-*.yaml || echo "No changes to add"
                                git commit -m "Auto-update: Set image tag to prod [BUILD ${env.BUILD_NUMBER}]" || echo "Nothing to commit"
                                git push origin main
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: "${SLACK_CHANNEL}", message: "✅ *Pipeline Successful Vishy*: `${JOB_NAME}` build #${BUILD_NUMBER} (<${BUILD_URL}|View Build>)")
        }
        failure {
            slackSend(channel: "${SLACK_CHANNEL}", message: "🚨 *Pipeline Failed Vishy*: `${JOB_NAME}` build #${BUILD_NUMBER} (<${BUILD_URL}|View Build>)")
        }
        always {
            cleanWs()
        }
    }
}