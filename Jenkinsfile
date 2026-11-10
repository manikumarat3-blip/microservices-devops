pipeline {

    agent any

    options {
        timestamps()
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {

        // AWS
        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '368451698271'

        // ECR
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        USER_REPO = "${ECR_REGISTRY}/microservices-devops/user-service"
        PRODUCT_REPO = "${ECR_REGISTRY}/microservices-devops/product-service"
        ORDER_REPO = "${ECR_REGISTRY}/microservices-devops/order-service"

        IMAGE_TAG = '1.0.0'

        USER_IMAGE = "${USER_REPO}:${IMAGE_TAG}"
        PRODUCT_IMAGE = "${PRODUCT_REPO}:${IMAGE_TAG}"
        ORDER_IMAGE = "${ORDER_REPO}:${IMAGE_TAG}"

        // EC2
        EC2_HOST = '16.176.148.52'
        EC2_USER = 'ubuntu'
        DEPLOY_DIR = '/home/ubuntu/microservices-devops'

        // Jenkins Credentials
        AWS_CREDENTIALS_ID = 'aws-ecr-credentials'
        SSH_CREDENTIALS_ID = 'ec2-ssh-key'
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
                    set -eu

                    echo "======================================"
                    echo "VALIDATING ENVIRONMENT"
                    echo "======================================"

                    docker --version
                    docker compose version

                    echo ""
                    echo "Validating local Compose file..."

                    timeout 30s docker compose \
                        -f docker-compose.yml \
                        config -q

                    echo "Local Compose validation successful."

                    echo ""
                    echo "Validating EC2 Compose file..."

                    USER_IMAGE=validation/user:latest \
                    PRODUCT_IMAGE=validation/product:latest \
                    ORDER_IMAGE=validation/order:latest \
                    timeout 30s docker compose \
                        -f docker-compose.ec2.yml \
                        config -q

                    echo "EC2 Compose validation successful."
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    set -eu

                    echo "======================================"
                    echo "BUILDING DOCKER IMAGES"
                    echo "======================================"

                    docker build \
                        -t user-service:${IMAGE_TAG} \
                        ./user-service

                    docker build \
                        -t product-service:${IMAGE_TAG} \
                        ./product-service

                    docker build \
                        -t order-service:${IMAGE_TAG} \
                        ./order-service

                    echo ""
                    echo "Built images:"
                    docker images | grep -E 'user-service|product-service|order-service'
                '''
            }
        }

        stage('Test Images') {
            steps {
                sh '''
                    set -eu

                    echo "======================================"
                    echo "TESTING MICROSERVICES"
                    echo "======================================"

                    NETWORK="microservices-test-network"

                    # Clean old test resources
                    docker rm -f \
                        user-service-test \
                        product-service-test \
                        order-service-test \
                        2>/dev/null || true

                    docker network rm "$NETWORK" 2>/dev/null || true

                    docker network create "$NETWORK"

                    # Start User Service
                    docker run -d \
                        --name user-service-test \
                        --network "$NETWORK" \
                        -p 18001:8001 \
                        user-service:${IMAGE_TAG}

                    # Start Product Service
                    docker run -d \
                        --name product-service-test \
                        --network "$NETWORK" \
                        -p 18002:8002 \
                        product-service:${IMAGE_TAG}

                    # Start Order Service
                    docker run -d \
                        --name order-service-test \
                        --network "$NETWORK" \
                        -p 18003:8003 \
                        -e USER_SERVICE_URL=http://user-service-test:8001 \
                        -e PRODUCT_SERVICE_URL=http://product-service-test:8002 \
                        order-service:${IMAGE_TAG}

                    echo ""
                    echo "Waiting for services..."
                    sleep 5

                    echo ""
                    echo "Testing User Service..."
                    curl --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://localhost:18001/health

                    echo ""
                    echo "Testing Product Service..."
                    curl --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://localhost:18002/health

                    echo ""
                    echo "Testing Order Service..."
                    curl --fail \
                        --silent \
                        --show-error \
                        --max-time 10 \
                        http://localhost:18003/health

                    echo ""
                    echo "All microservices passed health checks."
                '''
            }

            post {
                always {
                    sh '''
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

        stage('Tag Images') {
            steps {
                sh '''
                    set -eu

                    echo "======================================"
                    echo "TAGGING IMAGES FOR ECR"
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

                    echo ""
                    echo "ECR tags created successfully."
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
                        set -eu

                        echo "======================================"
                        echo "LOGIN TO AMAZON ECR"
                        echo "======================================"

                        aws sts get-caller-identity

                        aws ecr get-login-password \
                            --region "${AWS_REGION}" \
                        | docker login \
                            --username AWS \
                            --password-stdin "${ECR_REGISTRY}"

                        echo "ECR login successful."
                    '''
                }
            }
        }

        stage('Push Images') {
            steps {
                sh '''
                    set -eu

                    echo "======================================"
                    echo "PUSHING IMAGES TO ECR"
                    echo "======================================"

                    docker push "${USER_IMAGE}"
                    docker push "${PRODUCT_IMAGE}"
                    docker push "${ORDER_IMAGE}"

                    echo ""
                    echo "All images pushed successfully."
                '''
            }
        }

        stage('Copy Deployment Files') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -eu

                        echo "======================================"
                        echo "COPYING DEPLOYMENT FILES"
                        echo "======================================"

                        ssh -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            "${EC2_USER}@${EC2_HOST}" \
                            "mkdir -p ${DEPLOY_DIR}/nginx"

                        scp -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            docker-compose.ec2.yml \
                            "${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/docker-compose.ec2.yml"

                        scp -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            nginx/nginx.conf \
                            "${EC2_USER}@${EC2_HOST}:${DEPLOY_DIR}/nginx/nginx.conf"

                        echo "Deployment files copied successfully."
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -eu

                        echo "======================================"
                        echo "DEPLOYING TO EC2"
                        echo "======================================"

                        ssh -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            "${EC2_USER}@${EC2_HOST}" << EOF

                            set -eu

                            cd "${DEPLOY_DIR}"

                            echo "Checking AWS CLI..."
                            aws --version

                            echo "Checking AWS identity..."
                            aws sts get-caller-identity

                            echo "Logging into ECR..."

                            aws ecr get-login-password \
                                --region "${AWS_REGION}" \
                            | docker login \
                                --username AWS \
                                --password-stdin \
                                "${ECR_REGISTRY}"

                            echo "Pulling latest images..."

                            docker pull "${USER_IMAGE}"
                            docker pull "${PRODUCT_IMAGE}"
                            docker pull "${ORDER_IMAGE}"

                            echo "Stopping old deployment..."

                            USER_IMAGE="${USER_IMAGE}" \
                            PRODUCT_IMAGE="${PRODUCT_IMAGE}" \
                            ORDER_IMAGE="${ORDER_IMAGE}" \
                            docker compose \
                                -f docker-compose.ec2.yml \
                                down

                            echo "Starting new deployment..."

                            USER_IMAGE="${USER_IMAGE}" \
                            PRODUCT_IMAGE="${PRODUCT_IMAGE}" \
                            ORDER_IMAGE="${ORDER_IMAGE}" \
                            docker compose \
                                -f docker-compose.ec2.yml \
                                up -d

                            echo "Waiting for containers..."
                            sleep 15

                            echo ""
                            echo "Container status:"
                            docker compose \
                                -f docker-compose.ec2.yml \
                                ps

EOF

                        echo "EC2 deployment completed."
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -eu

                        echo "======================================"
                        echo "VERIFYING DEPLOYMENT"
                        echo "======================================"

                        ssh -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            "${EC2_USER}@${EC2_HOST}" << EOF

                            set -eu

                            echo "Checking containers..."

                            docker ps \
                                --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'

                            echo ""
                            echo "Checking User Service..."

                            curl --fail \
                                --silent \
                                --show-error \
                                --max-time 10 \
                                http://localhost:8001/health

                            echo ""
                            echo "Checking Product Service..."

                            curl --fail \
                                --silent \
                                --show-error \
                                --max-time 10 \
                                http://localhost:8002/health

                            echo ""
                            echo "Checking Order Service..."

                            curl --fail \
                                --silent \
                                --show-error \
                                --max-time 10 \
                                http://localhost:8003/health

                            echo ""
                            echo "Checking Nginx..."

                            curl --fail \
                                --silent \
                                --show-error \
                                --max-time 10 \
                                http://localhost/health

                            echo ""
                            echo "Deployment verification successful."

EOF
                    '''
                }
            }
        }
    }

    post {

        success {
            echo '''
========================================
PIPELINE SUCCESS
========================================

Microservices CI/CD completed successfully.

Services:
- User Service
- Product Service
- Order Service
- Nginx

Docker Images:
- Built
- Tested
- Tagged
- Pushed to ECR
- Deployed to EC2
- Verified
========================================
'''
        }

        failure {
            echo '''
========================================
PIPELINE FAILED
========================================

Check the failed stage and Jenkins console
output for the exact error.
========================================
'''
        }

        always {
            sh '''
                docker rm -f \
                    user-service-test \
                    product-service-test \
                    order-service-test \
                    2>/dev/null || true

                docker network rm \
                    microservices-test-network \
                    2>/dev/null || true

                docker image prune -f || true
            '''
        }
    }
}

