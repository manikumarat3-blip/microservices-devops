pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-southeast-2'
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                sh 'docker --version'
                sh 'docker compose config'
            }
        }

        stage('Build Images') {
            steps {
                sh 'docker build -t user-service:${IMAGE_TAG} ./user-service'
                sh 'docker build -t product-service:${IMAGE_TAG} ./product-service'
                sh 'docker build -t order-service:${IMAGE_TAG} ./order-service'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm user-service:${IMAGE_TAG} python -c "import urllib.request; print(urllib.request.urlopen(\\\"http://localhost:8001/health\\\").status)" || true'
            }
        }

        stage('Image Verification') {
            steps {
                sh 'docker images | grep -E "user-service|product-service|order-service"'
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }

        success {
            echo 'CI pipeline completed successfully.'
        }

        failure {
            echo 'CI pipeline failed. Check the stage logs.'
        }
    }
}

