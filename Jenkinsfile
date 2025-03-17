pipeline {
    agent any
    
    environment {
        DOCKERHUB_USERNAME = credentials('dockerhub-username')
        DOCKERHUB_PASSWORD = credentials('dockerhub-password')
        IMAGE_NAME = 'your-dockerhub-username/flask-aws-monitor'
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: "https://github.com/AviBernstock/DevOpsPracticalExam.git"
            }
        }
        
        stage('Parallel Checks') {
            parallel {
                stage('Linting') {
                    steps {
                        script {
                            sh 'flake8 . || true' // Python linting
                            sh 'shellcheck *.sh || true' // Shell script linting
                            sh 'hadolint Dockerfile || true' // Dockerfile linting
                        }
                    }
                }
                stage('Security Scan') {
                    steps {
                        script {
                            sh 'bandit -r . || true' // Python security scan
                            sh 'trivy image $IMAGE_NAME || true' // Docker image security scan
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t $IMAGE_NAME .'
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    sh 'echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USERNAME --password-stdin'
                    sh 'docker push $IMAGE_NAME'
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed! Check logs for details.'
        }
    }
}
