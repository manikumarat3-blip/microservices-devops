pipeline {

    agent any

    environment {

        // =========================================================
        // AWS CONFIGURATION
        // =========================================================

        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '368451698271'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        // =========================================================
        // ECR REPOSITORIES
        // =========================================================

        USER_REPO = "${ECR_REGISTRY}/microservices-devops/user-service"
        PRODUCT_REPO = "${ECR_REGISTRY}/microservices-devops/product-service"
        ORDER_REPO = "${ECR_REGISTRY}/microservices-devops/order-service"

        // =========================================================
        // IMAGE TAG
        // =========================================================

        IMAGE_TAG = '1.0.0'

        USER_IMAGE = "${USER_REPO}:${IMAGE_TAG}"
        PRODUCT_IMAGE = "${PRODUCT_REPO}:${IMAGE_TAG}"
        ORDER_IMAGE = "${ORDER_REPO}:${IMAGE_TAG}"

        // =========================================================
        // EC2 CONFIGURATION
        // =========================================================

        EC2_HOST = '16.176.148.52'
        EC2_USER = 'ubuntu'

        DEPLOY_DIR = '/home/ubuntu/microservices-devops'

        // =========================================================
        // JENKINS CREDENTIALS
        // =========================================================

        AWS_CREDENTIALS_ID = 'aws-ecr-credentials'
        SSH_CREDENTIALS_ID = 'ec2-ssh-key'
    }


    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================

        stage('Checkout') {

            steps {

                echo '======================================'
                echo 'Checking out source code'
                echo '======================================'

                checkout scm

                sh '''
                    set -e

                    echo "Current commit:"
                    git rev-parse --short HEAD

                    echo "Current branch:"
                    git branch --show-current

                    echo "Repository contents:"
                    ls -la
                '''
            }
        }


        // =========================================================
        // 2. VALIDATE
        // =========================================================

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

                    docker compose \
                        -f docker-compose.yml \
                        config

                    echo "Local docker-compose.yml is valid."


                    echo "======================================"
                    echo "Validating EC2 Docker Compose"
                    echo "======================================"

                    USER_IMAGE=validation/user:latest \
                    PRODUCT_IMAGE=validation/product:latest \
                    ORDER_IMAGE=validation/order:latest \
                    docker compose \
                        -f docker-compose.ec2.yml \
                        config

                    echo "EC2 docker-compose.ec2.yml is valid."


                    echo "======================================"
                    echo "Validation Successful"
                    echo "======================================"
                '''
            }
        }


        // =========================================================
        // 3. BUILD IMAGES
        // =========================================================

        stage('Build Images') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo "Building user-service"
                    echo "======================================"

                    docker build \
                        -t user-service:${IMAGE_TAG} \
                        ./user-service


                    echo "======================================"
                    echo "Building product-service"
                    echo "======================================"

                    docker build \
                        -t product-service:${IMAGE_TAG} \
                        ./product-service


                    echo "======================================"
                    echo "Building order-service"
                    echo "======================================"

                    docker build \
                        -t order-service:${IMAGE_TAG} \
                        ./order-service


                    echo "======================================"
                    echo "Images Built Successfully"
                    echo "======================================"

                    docker images | grep -E \
                        'user-service|product-service|order-service'
                '''
            }
        }


        // =========================================================
        // 4. TEST IMAGES
        // =========================================================

        stage('Test Images') {

            steps {

                sh '''
                    set -eu

                    echo "======================================"
                    echo "Starting Image Tests"
                    echo "======================================"

                    NETWORK="microservices-test-network"


                    echo "Cleaning previous test resources..."

                    docker rm -f \
                        user-service-test \
                        product-service-test \
                        order-service-test \
                        2>/dev/null || true

                    docker network rm \
                        "$NETWORK" \
                        2>/dev/null || true


                    echo "Creating test network..."

                    docker network create "$NETWORK"


                    echo "======================================"
                    echo "Starting user-service"
                    echo "======================================"

                    docker run -d \
                        --name user-service-test \
                        --network "$NETWORK" \
                        -p 18001:8001 \
                        user-service:${IMAGE_TAG}


                    echo "======================================"
                    echo "Starting product-service"
                    echo "======================================"

                    docker run -d \
                        --name product-service-test \
                        --network "$NETWORK" \
                        -p 18002:8002 \
                        product-service:${IMAGE_TAG}


                    echo "======================================"
                    echo "Starting order-service"
                    echo "======================================"

                    docker run -d \
                        --name order-service-test \
                        --network "$NETWORK" \
                        -p 18003:8003 \
                        -e USER_SERVICE_URL=http://user-service-test:8001 \
                        -e PRODUCT_SERVICE_URL=http://product-service-test:8002 \
                        order-service:${IMAGE_TAG}


                    echo "======================================"
                    echo "Waiting for services"
                    echo "======================================"

                    sleep 5


                    echo "======================================"
                    echo "Testing user-service"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://localhost:18001/health

                    echo ""
                    echo "User service test PASSED"


                    echo "======================================"
                    echo "Testing product-service"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://localhost:18002/health

                    echo ""
                    echo "Product service test PASSED"


                    echo "======================================"
                    echo "Testing order-service"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://localhost:18003/health

                    echo ""
                    echo "Order service test PASSED"


                    echo "======================================"
                    echo "All Image Tests PASSED"
                    echo "======================================"
                '''
            }


            post {

                always {

                    sh '''
                        echo "======================================"
                        echo "Cleaning Test Containers"
                        echo "======================================"

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


        // =========================================================
        // 5. TAG IMAGES
        // =========================================================

        stage('Tag Images') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo "Tagging Images for ECR"
                    echo "======================================"

                    docker tag \
                        user-service:${IMAGE_TAG} \
                        ${USER_IMAGE}

                    docker tag \
                        product-service:${IMAGE_TAG} \
                        ${PRODUCT_IMAGE}

                    docker tag \
                        order-service:${IMAGE_TAG} \
                        ${ORDER_IMAGE}


                    echo "ECR tags created."

                    docker images | grep \
                        '368451698271.dkr.ecr.ap-southeast-2.amazonaws.com'
                '''
            }
        }


        // =========================================================
        // 6. ECR LOGIN
        // =========================================================

        stage('ECR Login') {

            steps {

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: "${AWS_CREDENTIALS_ID}"]
                ]) {

                    sh '''
                        set -e

                        echo "======================================"
                        echo "Logging into Amazon ECR"
                        echo "======================================"

                        aws sts get-caller-identity

                        aws ecr get-login-password \
                            --region ${AWS_REGION} |
                        docker login \
                            --username AWS \
                            --password-stdin ${ECR_REGISTRY}

                        echo "ECR login successful."
                    '''
                }
            }
        }


        // =========================================================
        // 7. PUSH IMAGES
        // =========================================================

        stage('Push Images') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo "Pushing user-service"
                    echo "======================================"

                    docker push ${USER_IMAGE}


                    echo "======================================"
                    echo "Pushing product-service"
                    echo "======================================"

                    docker push ${PRODUCT_IMAGE}


                    echo "======================================"
                    echo "Pushing order-service"
                    echo "======================================"

                    docker push ${ORDER_IMAGE}


                    echo "======================================"
                    echo "All Images Pushed Successfully"
                    echo "======================================"
                '''
            }
        }


        // =========================================================
        // 8. DEPLOY TO EC2
        // =========================================================

        stage('Deploy to EC2') {

            steps {

                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: "${AWS_CREDENTIALS_ID}"]
                    ]) {

                        sh '''
                            set -e

                            echo "======================================"
                            echo "Preparing EC2"
                            echo "======================================"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "mkdir -p ${DEPLOY_DIR}/nginx"


                            echo "======================================"
                            echo "Checking EC2 Docker"
                            echo "======================================"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker --version && docker compose version"


                            echo "======================================"
                            echo "Checking EC2 AWS CLI"
                            echo "======================================"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "aws --version"


                            echo "======================================"
                            echo "Logging EC2 into ECR"
                            echo "======================================"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"


                            echo "======================================"
                            echo "Pulling Images on EC2"
                            echo "======================================"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker pull ${USER_IMAGE}"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker pull ${PRODUCT_IMAGE}"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                ${EC2_USER}@${EC2_HOST} \
                                "docker pull ${ORDER_IMAGE}"


                            echo "======================================"
                            echo "EC2 Images Pulled Successfully"
                            echo "======================================"
                        '''
                    }
                }
            }
        }


        // =========================================================
        // 9. COPY DEPLOYMENT FILES
        // =========================================================

        stage('Copy Deployment Files') {

            steps {

                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {

                    sh '''
                        set -e

                        echo "======================================"
                        echo "Copying Docker Compose"
                        echo "======================================"

                        scp \
                            -o StrictHostKeyChecking=no \
                            docker-compose.ec2.yml \
                            ${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/docker-compose.ec2.yml


                        echo "======================================"
                        echo "Copying Nginx Configuration"
                        echo "======================================"

                        scp \
                            -o StrictHostKeyChecking=no \
                            nginx/nginx.conf \
                            ${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/nginx/nginx.conf


                        echo "Deployment files copied successfully."
                    '''
                }
            }
        }


        // =========================================================
        // 10. DEPLOY COMPOSE
        // =========================================================

        stage('Deploy Compose') {

            steps {

                sshagent(credentials: ["${SSH_CREDENTIALS_ID}"]) {

                    sh '''
                        set -e

                        echo "======================================"
                        echo "Deploying Microservices"
                        echo "======================================"

                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "cd ${DEPLOY_DIR} && \
                             export USER_IMAGE='${USER_IMAGE}' && \
                             export PRODUCT_IMAGE='${PRODUCT_IMAGE}' && \
                             export ORDER_IMAGE='${ORDER_IMAGE}' && \
                             docker compose \
                                -f docker-compose.ec2.yml \
                                pull"


                        echo "Starting containers..."

                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "cd ${DEPLOY_DIR} && \
                             export USER_IMAGE='${USER_IMAGE}' && \
                             export PRODUCT_IMAGE='${PRODUCT_IMAGE}' && \
                             export ORDER_IMAGE='${ORDER_IMAGE}' && \
                             docker compose \
                                -f docker-compose.ec2.yml \
                                up -d --remove-orphans"


                        echo "======================================"
                        echo "Docker Compose Status"
                        echo "======================================"

                        ssh \
                            -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "cd ${DEPLOY_DIR} && \
                             export USER_IMAGE='${USER_IMAGE}' && \
                             export PRODUCT_IMAGE='${PRODUCT_IMAGE}' && \
                             export ORDER_IMAGE='${ORDER_IMAGE}' && \
                             docker compose \
                                -f docker-compose.ec2.yml \
                                ps"
                    '''
                }
            }
        }


        // =========================================================
        // 11. VERIFY DEPLOYMENT
        // =========================================================

        stage('Verify Deployment') {

            steps {

                sh '''
                    set -e

                    echo "======================================"
                    echo "Waiting for containers to become healthy"
                    echo "======================================"

                    sleep 15


                    echo "======================================"
                    echo "Checking EC2 Containers"
                    echo "======================================"

                    ssh \
                        -o StrictHostKeyChecking=no \
                        ${EC2_USER}@${EC2_HOST} \
                        "docker ps"


                    echo "======================================"
                    echo "Checking User Service"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://${EC2_HOST}:8001/health

                    echo ""


                    echo "======================================"
                    echo "Checking Product Service"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://${EC2_HOST}:8002/health

                    echo ""


                    echo "======================================"
                    echo "Checking Order Service"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://${EC2_HOST}:8003/health

                    echo ""


                    echo "======================================"
                    echo "Checking Nginx"
                    echo "======================================"

                    curl \
                        --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://${EC2_HOST}/health

                    echo ""


                    echo "======================================"
                    echo "Deployment Verification Successful"
                    echo "======================================"
                '''
            }
        }
    }


    // =============================================================
    // POST ACTIONS
    // =============================================================

    post {

        success {

            echo '''
======================================
PIPELINE SUCCESS
======================================
Microservices CI/CD pipeline completed successfully.

Services:
- user-service
- product-service
- order-service
- nginx

Deployment:
EC2: ${EC2_HOST}

======================================
'''
        }


        failure {

            echo '''
======================================
PIPELINE FAILED
======================================
Please check the Jenkins console output
for the failed stage.
======================================
'''
        }


        always {

            sh '''
                echo "======================================"
                echo "Docker Cleanup"
                echo "======================================"

                docker image prune -f || true
            '''
        }
    }
}

