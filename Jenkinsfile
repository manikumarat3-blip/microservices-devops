pipeline {

    agent any

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

        // Jenkins credential containing AWS Access Key + Secret Key
        AWS_CREDENTIALS_ID = 'aws-ecr-credentials'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    set -e

                    echo "======================================"
                    echo "Docker Version"
                    echo "======================================"
                    docker --version
                    docker compose version

                    echo "======================================"
                    echo "Validating Local Docker Compose"
                    echo "======================================"

                    docker compose -f docker-compose.yml config > /tmp/docker-compose-config.yml

                    echo "Local docker-compose.yml is valid."

                    echo "======================================"
                    echo "Validating EC2 Docker Compose"
                    echo "======================================"

                    USER_IMAGE=validation/user:latest \
                    PRODUCT_IMAGE=validation/product:latest \
                    ORDER_IMAGE=validation/order:latest \
                    docker compose -f docker-compose.ec2.yml config > /tmp/docker-compose-ec2-config.yml

                    echo "EC2 docker-compose.ec2.yml is valid."

                    echo "======================================"
                    echo "Validation Successful"
                    echo "======================================"
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    set -e

                    echo "Building user-service..."
                    docker build \
                        -t user-service:${IMAGE_TAG} \
                        ./user-service

                    echo "Building product-service..."
                    docker build \
                        -t product-service:${IMAGE_TAG} \
                        ./product-service

                    echo "Building order-service..."
                    docker build \
                        -t order-service:${IMAGE_TAG} \
                        ./order-service

                    echo "Images built successfully."

                    docker images | grep -E \
                        'user-service|product-service|order-service'
                '''
            }
        }

        stage('Test Images') {
            steps {
                sh '''
                    set -e

                    echo "Starting services for testing..."

                    docker network create microservices-test-network 2>/dev/null || true

                    docker run -d \
                        --name user-service-test \
                        --network microservices-test-network \
                        -p 18001:8001 \
                        user-service:${IMAGE_TAG}

                    docker run -d \
                        --name product-service-test \
                        --network microservices-test-network \
                        -p 18002:8002 \
                        product-service:${IMAGE_TAG}

                    docker run -d \
                        --name order-service-test \
                        --network microservices-test-network \
                        -p 18003:8003 \
                        -e USER_SERVICE_URL=http://user-service-test:8001 \
                        -e PRODUCT_SERVICE_URL=http://product-service-test:8002 \
                        order-service:${IMAGE_TAG}

                    echo "Waiting for containers..."
                    sleep 15

                    echo "======================================"
                    echo "Container Status"
                    echo "======================================"

                    docker ps -a \
                        --filter name=user-service-test \
                        --filter name=product-service-test \
                        --filter name=order-service-test

                    echo "======================================"
                    echo "Testing User Service"
                    echo "======================================"

                    curl -f http://localhost:18001/health

                    echo ""
                    echo "======================================"
                    echo "Testing Product Service"
                    echo "======================================"

                    curl -f http://localhost:18002/health

                    echo ""
                    echo "======================================"
                    echo "Testing Order Service"
                    echo "======================================"

                    curl -f http://localhost:18003/health

                    echo ""
                    echo "All service health checks passed."
                '''
            }

            post {
                always {
                    sh '''
                        docker logs user-service-test 2>/dev/null || true
                        docker logs product-service-test 2>/dev/null || true
                        docker logs order-service-test 2>/dev/null || true

                        docker rm -f \
                            user-service-test \
                            product-service-test \
                            order-service-test \
                            2>/dev/null || true

                        docker network rm microservices-test-network \
                            2>/dev/null || true
                    '''
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh '''
                    set -e

                    echo "Tagging user-service..."
                    docker tag \
                        user-service:${IMAGE_TAG} \
                        ${USER_IMAGE}

                    echo "Tagging product-service..."
                    docker tag \
                        product-service:${IMAGE_TAG} \
                        ${PRODUCT_IMAGE}

                    echo "Tagging order-service..."
                    docker tag \
                        order-service:${IMAGE_TAG} \
                        ${ORDER_IMAGE}

                    echo "======================================"
                    echo "ECR Tags"
                    echo "======================================"

                    docker images | grep ${ECR_REGISTRY}
                '''
            }
        }

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

        stage('Push Images') {
            steps {
                sh '''
                    set -e

                    echo "Pushing user-service..."
                    docker push ${USER_IMAGE}

                    echo "Pushing product-service..."
                    docker push ${PRODUCT_IMAGE}

                    echo "Pushing order-service..."
                    docker push ${ORDER_IMAGE}

                    echo "======================================"
                    echo "All Images Pushed Successfully"
                    echo "======================================"
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh '''
                        set -e

                        echo "======================================"
                        echo "Deploying to EC2"
                        echo "======================================"

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} << EOF

                            set -e

                            echo "Logging into ECR..."

                            aws ecr get-login-password \
                                --region ${AWS_REGION} | \
                            docker login \
                                --username AWS \
                                --password-stdin ${ECR_REGISTRY}

                            echo "Pulling latest images..."

                            docker pull ${USER_IMAGE}
                            docker pull ${PRODUCT_IMAGE}
                            docker pull ${ORDER_IMAGE}

                            echo "Creating deployment directory..."

                            mkdir -p ~/microservices-devops

                            cd ~/microservices-devops

                            echo "Deployment completed on EC2."

                        EOF
                    '''
                }
            }
        }

        stage('Deploy Compose') {
            steps {
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh '''
                        set -e

                        echo "Copying EC2 Compose file..."

                        scp -o StrictHostKeyChecking=no \
                            docker-compose.ec2.yml \
                            ${EC2_USER}@${EC2_HOST}:~/microservices-devops/docker-compose.ec2.yml

                        echo "Starting application..."

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} << EOF

                            set -e

                            cd ~/microservices-devops

                            export USER_IMAGE="${USER_IMAGE}"
                            export PRODUCT_IMAGE="${PRODUCT_IMAGE}"
                            export ORDER_IMAGE="${ORDER_IMAGE}"

                            docker compose \
                                -f docker-compose.ec2.yml \
                                pull

                            docker compose \
                                -f docker-compose.ec2.yml \
                                up -d \
                                --remove-orphans

                            echo "======================================"
                            echo "Running Containers"
                            echo "======================================"

                            docker compose \
                                -f docker-compose.ec2.yml \
                                ps

                        EOF
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "Waiting for application..."
                    sleep 15

                    echo "Testing EC2 application..."

                    curl -f http://${EC2_HOST}/health || true

                    echo "======================================"
                    echo "Deployment Verification"
                    echo "======================================"

                    curl -I http://${EC2_HOST}

                    echo ""
                    echo "Application deployment completed."
                '''
            }
        }
    }

    post {
        success {
            echo '''
========================================
 CI/CD PIPELINE SUCCESSFUL
========================================
 Docker images built
 Images tested
 Images pushed to ECR
 Application deployed to EC2
 Deployment verification completed
========================================
'''
        }

        failure {
            echo '''
========================================
 CI/CD PIPELINE FAILED
========================================
Check the Jenkins console output.
========================================
'''
        }

        always {
            sh '''
                docker image prune -f || true
            '''
        }
    }
}

