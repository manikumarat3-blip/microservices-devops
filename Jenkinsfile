pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '368451698271'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        USER_REPO = "${ECR_REGISTRY}/microservices-devops/user-service"
        PRODUCT_REPO = "${ECR_REGISTRY}/microservices-devops/product-service"
        ORDER_REPO = "${ECR_REGISTRY}/microservices-devops/order-service"

        IMAGE_TAG = '1.0.0'

        USER_IMAGE = "${USER_REPO}:${IMAGE_TAG}"
        PRODUCT_IMAGE = "${PRODUCT_REPO}:${IMAGE_TAG}"
        ORDER_IMAGE = "${ORDER_REPO}:${IMAGE_TAG}"

        EC2_HOST = '16.176.148.52'
        EC2_USER = 'ubuntu'

        AWS_CREDENTIALS_ID = 'aws-ecr-credentials'
        SSH_CREDENTIALS_ID = 'ec2-ssh-key'

        DEPLOY_DIR = '/home/ubuntu/microservices-devops'

        TEST_NETWORK = 'microservices-test-network'
        TEST_USER_CONTAINER = 'user-service-test'
        TEST_PRODUCT_CONTAINER = 'product-service-test'
        TEST_ORDER_CONTAINER = 'order-service-test'
    }

    stages {

        // ============================================================
        // 1. CHECKOUT
        // ============================================================

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ============================================================
        // 2. VALIDATE
        // ============================================================

        stage('Validate') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Docker Version"
                    echo "=========================================="
                    docker --version

                    echo "=========================================="
                    echo "Docker Compose Version"
                    echo "=========================================="
                    docker compose version

                    echo "=========================================="
                    echo "Validating docker-compose.yml"
                    echo "=========================================="
                    docker compose -f docker-compose.yml config -q

                    echo "=========================================="
                    echo "Validating docker-compose.ec2.yml"
                    echo "=========================================="

                    USER_IMAGE=validation/user:latest \
                    PRODUCT_IMAGE=validation/product:latest \
                    ORDER_IMAGE=validation/order:latest \
                    docker compose -f docker-compose.ec2.yml config -q

                    echo "Compose validation successful."
                '''
            }
        }

        // ============================================================
        // 3. BUILD IMAGES
        // ============================================================

        stage('Build Images') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Building User Service"
                    echo "=========================================="
                    docker build \
                        -t user-service:${IMAGE_TAG} \
                        ./user-service

                    echo "=========================================="
                    echo "Building Product Service"
                    echo "=========================================="
                    docker build \
                        -t product-service:${IMAGE_TAG} \
                        ./product-service

                    echo "=========================================="
                    echo "Building Order Service"
                    echo "=========================================="
                    docker build \
                        -t order-service:${IMAGE_TAG} \
                        ./order-service

                    echo "All Docker images built successfully."

                    docker images | grep -E \
                        'user-service|product-service|order-service'
                '''
            }
        }

        // ============================================================
        // 4. TEST IMAGES
        // ============================================================

        stage('Test Images') {
    steps {
        sh '''
            set -e

            echo "=========================================="
            echo "Cleaning previous test resources..."
            echo "=========================================="

            docker rm -f user-service-test product-service-test order-service-test 2>/dev/null || true
            docker network rm microservices-test-network 2>/dev/null || true

            docker network create microservices-test-network

            echo "Starting User Service test container..."
            docker run -d \
              --name user-service-test \
              --network microservices-test-network \
              -e SERVICE_NAME=user-service \
              -e SERVICE_PORT=8001 \
              user-service:1.0.0

            echo "Starting Product Service test container..."
            docker run -d \
              --name product-service-test \
              --network microservices-test-network \
              -e SERVICE_NAME=product-service \
              -e SERVICE_PORT=8002 \
              product-service:1.0.0

            echo "Starting Order Service test container..."
            docker run -d \
              --name order-service-test \
              --network microservices-test-network \
              -e SERVICE_NAME=order-service \
              -e SERVICE_PORT=8003 \
              -e USER_SERVICE_URL=http://user-service-test:8001 \
              -e PRODUCT_SERVICE_URL=http://product-service-test:8002 \
              order-service:1.0.0

            echo "Waiting for containers to start..."
            sleep 10

            echo "=========================================="
            echo "User Service Health Check"
            echo "=========================================="

            docker exec user-service-test \
              python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')"

            echo "User Service: HEALTHY"

            echo "=========================================="
            echo "Product Service Health Check"
            echo "=========================================="

            docker exec product-service-test \
              python -c "import urllib.request; urllib.request.urlopen('http://localhost:8002/health')"

            echo "Product Service: HEALTHY"

            echo "=========================================="
            echo "Order Service Health Check"
            echo "=========================================="

            docker exec order-service-test \
              python -c "import urllib.request; urllib.request.urlopen('http://localhost:8003/health')"

            echo "Order Service: HEALTHY"

            echo "=========================================="
            echo "All Docker Image Tests Passed"
            echo "=========================================="
        '''
    }

    post {
        always {
            sh '''
                echo "Cleaning test containers..."

                docker rm -f \
                  user-service-test \
                  product-service-test \
                  order-service-test \
                  2>/dev/null || true

                docker network rm \
                  microservices-test-network \
                  2>/dev/null || true
            '''
        }
    }
}
        // ============================================================
        // 5. TAG IMAGES
        // ============================================================

        stage('Tag Images') {
            steps {
                sh '''
                    set -e

                    docker tag \
                        user-service:${IMAGE_TAG} \
                        ${USER_IMAGE}

                    docker tag \
                        product-service:${IMAGE_TAG} \
                        ${PRODUCT_IMAGE}

                    docker tag \
                        order-service:${IMAGE_TAG} \
                        ${ORDER_IMAGE}

                    echo "Images tagged successfully."

                    docker images | grep ${ECR_REGISTRY}
                '''
            }
        }

        // ============================================================
        // 6. ECR LOGIN
        // ============================================================

        stage('ECR Login') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: "${AWS_CREDENTIALS_ID}"]
                ]) {
                    sh '''
                        set -e

                        echo "Logging into Amazon ECR..."

                        aws ecr get-login-password \
                            --region ${AWS_REGION} | \
                        docker login \
                            --username AWS \
                            --password-stdin ${ECR_REGISTRY}

                        echo "ECR login successful."
                    '''
                }
            }
        }

        // ============================================================
        // 7. PUSH IMAGES
        // ============================================================

        stage('Push Images') {
            steps {
                sh '''
                    set -e

                    echo "Pushing User Service..."
                    docker push ${USER_IMAGE}

                    echo "Pushing Product Service..."
                    docker push ${PRODUCT_IMAGE}

                    echo "Pushing Order Service..."
                    docker push ${ORDER_IMAGE}

                    echo "=========================================="
                    echo "All images pushed successfully."
                    echo "=========================================="

                    echo ${USER_IMAGE}
                    echo ${PRODUCT_IMAGE}
                    echo ${ORDER_IMAGE}
                '''
            }
        }

        // ============================================================
        // 8. DEPLOY TO EC2
        // ============================================================

        stage('Deploy to EC2') {
            steps {

                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: "${AWS_CREDENTIALS_ID}"]
                    ]) {

                        sh '''
                            set -e

                            echo "=========================================="
                            echo "Preparing EC2 Deployment"
                            echo "=========================================="

                            ssh -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "mkdir -p ${DEPLOY_DIR}/nginx"

                            echo "Copying Docker Compose file..."

                            scp -o StrictHostKeyChecking=no \
                                docker-compose.ec2.yml \
                                ${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/docker-compose.ec2.yml

                            echo "Copying Nginx configuration..."

                            scp -o StrictHostKeyChecking=no \
                                nginx/nginx.conf \
                                ${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/nginx/nginx.conf

                            echo "Deployment files copied successfully."

                            echo "Logging into ECR on EC2..."

                            ssh -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"

                            echo "Pulling latest images..."

                            ssh -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker pull ${USER_IMAGE}"

                            ssh -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker pull ${PRODUCT_IMAGE}"

                            ssh -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker pull ${ORDER_IMAGE}"

                            echo "Images pulled successfully."

                            echo "Starting application..."

                            ssh -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "cd ${DEPLOY_DIR} && \
                                 USER_IMAGE=${USER_IMAGE} \
                                 PRODUCT_IMAGE=${PRODUCT_IMAGE} \
                                 ORDER_IMAGE=${ORDER_IMAGE} \
                                 docker compose \
                                 -f docker-compose.ec2.yml \
                                 up -d \
                                 --remove-orphans"

                            echo "Application deployment completed."
                        '''
                    }
                }
            }
        }

        // ============================================================
        // 9. VERIFY DEPLOYMENT
        // ============================================================

        stage('Verify Deployment') {
            steps {

                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {

                    sh '''
                        set -e

                        echo "=========================================="
                        echo "Checking Running Containers"
                        echo "=========================================="

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "cd ${DEPLOY_DIR} && \
                             docker compose \
                             -f docker-compose.ec2.yml \
                             ps"

                        echo "=========================================="
                        echo "User Service Health"
                        echo "=========================================="

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "curl --fail --silent --show-error \
                             --max-time 10 \
                             http://localhost:8001/health"

                        echo

                        echo "=========================================="
                        echo "Product Service Health"
                        echo "=========================================="

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "curl --fail --silent --show-error \
                             --max-time 10 \
                             http://localhost:8002/health"

                        echo

                        echo "=========================================="
                        echo "Order Service Health"
                        echo "=========================================="

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "curl --fail --silent --show-error \
                             --max-time 10 \
                             http://localhost:8003/health"

                        echo

                        echo "=========================================="
                        echo "Nginx Health"
                        echo "=========================================="

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "curl --fail --silent --show-error \
                             --max-time 10 \
                             http://localhost/health"

                        echo

                        echo "=========================================="
                        echo "Deployment Verification Successful"
                        echo "=========================================="
                    '''
                }
            }
        }
    }

    // ================================================================
    // POST ACTIONS
    // ================================================================

    post {

        success {
            echo '''
==========================================
PIPELINE SUCCESS
==========================================
All microservices were:
1. Checked out
2. Validated
3. Built
4. Tested
5. Tagged
6. Pushed to Amazon ECR
7. Deployed to EC2
8. Health checked successfully
==========================================
'''
        }

        failure {
            echo '''
==========================================
PIPELINE FAILED
==========================================
Check the Jenkins console log for the
failed stage and error details.
==========================================
'''
        }

        always {
            sh '''
                echo "Cleaning unused Docker images..."

                docker image prune -f || true
            '''
        }
    }
}

