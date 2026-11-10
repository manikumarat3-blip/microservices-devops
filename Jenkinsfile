pipeline {

    agent any

    environment {
        AWS_REGION = 'ap-southeast-2'

        AWS_ACCOUNT_ID = '368451698271'

        ECR_REGISTRY = '368451698271.dkr.ecr.ap-southeast-2.amazonaws.com'

        IMAGE_TAG = '1.0.0'

        USER_IMAGE = '368451698271.dkr.ecr.ap-southeast-2.amazonaws.com/microservices-devops/user-service:1.0.0'
        PRODUCT_IMAGE = '368451698271.dkr.ecr.ap-southeast-2.amazonaws.com/microservices-devops/product-service:1.0.0'
        ORDER_IMAGE = '368451698271.dkr.ecr.ap-southeast-2.amazonaws.com/microservices-devops/order-service:1.0.0'

        EC2_HOST = '16.176.148.52'
        EC2_USER = 'ubuntu'
        EC2_APP_DIR = '/home/ubuntu/microservices-devops'
    }

    stages {

        /*
         * ============================================================
         * CHECKOUT
         * ============================================================
         */

        stage('Checkout') {
            steps {

                echo '=========================================='
                echo 'Checking Out Source Code'
                echo '=========================================='

                checkout scm

                sh '''
                    echo "Current directory:"
                    pwd

                    echo
                    echo "Git commit:"
                    git rev-parse --short HEAD

                    echo
                    echo "Git branch:"
                    git branch --show-current

                    echo
                    echo "Repository contents:"
                    ls -la
                '''
            }
        }


        /*
         * ============================================================
         * VALIDATE
         * ============================================================
         */

        stage('Validate') {
            steps {

                echo '=========================================='
                echo 'Validating Docker Environment'
                echo '=========================================='

                sh '''
                    set -e

                    echo "Docker version:"
                    docker --version

                    echo
                    echo "Docker Compose version:"
                    docker compose version

                    echo
                    echo "Validating docker-compose.yml:"
                    docker compose -f docker-compose.yml config -q

                    echo
                    echo "Validating docker-compose.ec2.yml:"
                    USER_IMAGE="${USER_IMAGE}" \
                    PRODUCT_IMAGE="${PRODUCT_IMAGE}" \
                    ORDER_IMAGE="${ORDER_IMAGE}" \
                    docker compose -f docker-compose.ec2.yml config -q

                    echo
                    echo "Docker Compose validation successful."
                '''
            }
        }


        /*
         * ============================================================
         * BUILD IMAGES
         * ============================================================
         */

        stage('Build Images') {
            steps {

                echo '=========================================='
                echo 'Building Docker Images'
                echo '=========================================='

                sh '''
                    set -e

                    echo "Building user-service..."
                    docker build \
                        -t user-service:${IMAGE_TAG} \
                        ./user-service

                    echo
                    echo "Building product-service..."
                    docker build \
                        -t product-service:${IMAGE_TAG} \
                        ./product-service

                    echo
                    echo "Building order-service..."
                    docker build \
                        -t order-service:${IMAGE_TAG} \
                        ./order-service

                    echo
                    echo "Docker images created:"
                    docker images | grep -E \
                        "user-service|product-service|order-service"
                '''
            }
        }


        /*
         * ============================================================
         * TEST IMAGES
         * ============================================================
         */

        stage('Test Images') {
            steps {

                echo '=========================================='
                echo 'Testing Docker Images'
                echo '=========================================='

                sh '''
                    set -e

                    NETWORK_NAME="microservices-test-network"

                    echo "Creating test network..."
                    docker network create ${NETWORK_NAME} 2>/dev/null || true

                    echo
                    echo "Removing old test containers..."
                    docker rm -f \
                        test-user-service \
                        test-product-service \
                        test-order-service \
                        2>/dev/null || true


                    echo
                    echo "Starting user-service..."
                    docker run -d \
                        --name test-user-service \
                        --network ${NETWORK_NAME} \
                        user-service:${IMAGE_TAG}


                    echo "Starting product-service..."
                    docker run -d \
                        --name test-product-service \
                        --network ${NETWORK_NAME} \
                        product-service:${IMAGE_TAG}


                    echo "Starting order-service..."
                    docker run -d \
                        --name test-order-service \
                        --network ${NETWORK_NAME} \
                        order-service:${IMAGE_TAG}


                    echo
                    echo "Waiting for applications..."
                    sleep 5


                    echo
                    echo "Testing user-service..."

                    docker exec test-user-service \
                        python -c "
import urllib.request
response = urllib.request.urlopen(
    'http://localhost:8001/health',
    timeout=5
)
print(response.read().decode())
"


                    echo
                    echo "Testing product-service..."

                    docker exec test-product-service \
                        python -c "
import urllib.request
response = urllib.request.urlopen(
    'http://localhost:8002/health',
    timeout=5
)
print(response.read().decode())
"


                    echo
                    echo "Testing order-service..."

                    docker exec test-order-service \
                        python -c "
import urllib.request
response = urllib.request.urlopen(
    'http://localhost:8003/health',
    timeout=5
)
print(response.read().decode())
"


                    echo
                    echo "All application health checks passed."


                    echo
                    echo "Removing test containers..."

                    docker rm -f \
                        test-user-service \
                        test-product-service \
                        test-order-service


                    echo
                    echo "Removing test network..."

                    docker network rm ${NETWORK_NAME} 2>/dev/null || true
                '''
            }
        }


        /*
         * ============================================================
         * TAG IMAGES
         * ============================================================
         */

        stage('Tag Images') {
            steps {

                echo '=========================================='
                echo 'Tagging Images For ECR'
                echo '=========================================='

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


                    echo
                    echo "ECR tagged images:"
                    docker images | grep \
                        "368451698271.dkr.ecr.ap-southeast-2.amazonaws.com"
                '''
            }
        }


        /*
         * ============================================================
         * ECR LOGIN
         * ============================================================
         */

        stage('ECR Login') {
            steps {

                echo '=========================================='
                echo 'Logging Into Amazon ECR'
                echo '=========================================='

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-ecr-credentials']
                ]) {

                    sh '''
                        set -e

                        aws --version

                        echo
                        echo "Logging into ECR..."

                        aws ecr get-login-password \
                            --region ${AWS_REGION} \
                        | docker login \
                            --username AWS \
                            --password-stdin ${ECR_REGISTRY}

                        echo
                        echo "ECR login successful."
                    '''
                }
            }
        }


        /*
         * ============================================================
         * PUSH IMAGES
         * ============================================================
         */

        stage('Push Images') {
            steps {

                echo '=========================================='
                echo 'Pushing Images To Amazon ECR'
                echo '=========================================='

                sh '''
                    set -e

                    echo "Pushing user-service..."
                    docker push ${USER_IMAGE}

                    echo
                    echo "Pushing product-service..."
                    docker push ${PRODUCT_IMAGE}

                    echo
                    echo "Pushing order-service..."
                    docker push ${ORDER_IMAGE}

                    echo
                    echo "All images pushed successfully."
                '''
            }
        }


        /*
         * ============================================================
         * DEPLOY TO EC2
         * ============================================================
         */

        stage('Deploy to EC2') {
            steps {

                echo '=========================================='
                echo 'Deploying Application To EC2'
                echo '=========================================='

                sshagent(['ec2-ssh-key']) {

                    sh '''
                        set -e

                        echo "Preparing EC2 application directory..."

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "mkdir -p ${EC2_APP_DIR}/nginx"


                        echo
                        echo "Copying Docker Compose file..."

                        scp -o StrictHostKeyChecking=no \
                            docker-compose.ec2.yml \
                            ${EC2_USER}@${EC2_HOST}:${EC2_APP_DIR}/docker-compose.ec2.yml


                        echo
                        echo "Copying Nginx configuration..."

                        scp -o StrictHostKeyChecking=no \
                            nginx/nginx.conf \
                            ${EC2_USER}@${EC2_HOST}:${EC2_APP_DIR}/nginx/nginx.conf


                        echo
                        echo "Logging into ECR on EC2..."

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} "
                                aws ecr get-login-password \
                                    --region ${AWS_REGION} \
                                | docker login \
                                    --username AWS \
                                    --password-stdin ${ECR_REGISTRY}
                            "


                        echo
                        echo "Pulling latest images on EC2..."

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} "
                                docker pull ${USER_IMAGE}
                                docker pull ${PRODUCT_IMAGE}
                                docker pull ${ORDER_IMAGE}
                            "


                        echo
                        echo "Starting application..."

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} "
                                cd ${EC2_APP_DIR} &&
                                export USER_IMAGE='${USER_IMAGE}' &&
                                export PRODUCT_IMAGE='${PRODUCT_IMAGE}' &&
                                export ORDER_IMAGE='${ORDER_IMAGE}' &&
                                docker compose \
                                    -f docker-compose.ec2.yml \
                                    up -d \
                                    --remove-orphans
                            "


                        echo
                        echo "Waiting for containers to become healthy..."

                        sleep 10


                        echo
                        echo "Application deployment completed."
                    '''
                }
            }
        }


        /*
         * ============================================================
         * VERIFY DEPLOYMENT
         * ============================================================
         */

        stage('Verify Deployment') {
            steps {

                echo '=========================================='
                echo 'Verifying EC2 Deployment'
                echo '=========================================='

                sshagent(['ec2-ssh-key']) {

                    sh '''
                        set -e


                        echo "=========================================="
                        echo "Checking Running Containers"
                        echo "=========================================="


                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} "
                                cd ${EC2_APP_DIR} &&
                                export USER_IMAGE='${USER_IMAGE}' &&
                                export PRODUCT_IMAGE='${PRODUCT_IMAGE}' &&
                                export ORDER_IMAGE='${ORDER_IMAGE}' &&
                                docker compose \
                                    -f docker-compose.ec2.yml \
                                    ps
                            "


                        echo
                        echo "=========================================="
                        echo "Checking Nginx Health"
                        echo "=========================================="


                        curl -f \
                            http://${EC2_HOST}/health


                        echo
                        echo
                        echo "=========================================="
                        echo "Checking User Service"
                        echo "=========================================="


                        curl -f \
                            http://${EC2_HOST}/users/health


                        echo
                        echo
                        echo "=========================================="
                        echo "Checking Product Service"
                        echo "=========================================="


                        curl -f \
                            http://${EC2_HOST}/products/health


                        echo
                        echo
                        echo "=========================================="
                        echo "Checking Order Service"
                        echo "=========================================="


                        curl -f \
                            http://${EC2_HOST}/orders/health


                        echo
                        echo
                        echo "=========================================="
                        echo "Deployment Verification Successful"
                        echo "=========================================="
                    '''
                }
            }
        }
    }


    /*
     * ================================================================
     * POST ACTIONS
     * ================================================================
     */

    post {

        success {

            echo '''
==========================================
PIPELINE SUCCESS
==========================================

Microservices CI/CD deployment completed successfully.

Services:
  - user-service
  - product-service
  - order-service
  - nginx

Docker Images:
  - ECR user-service
  - ECR product-service
  - ECR order-service

Deployment:
  - EC2 deployment successful
  - Container verification successful
  - Nginx health check successful
  - Application health checks successful

==========================================
'''
        }


        failure {

            echo '''
==========================================
PIPELINE FAILED
==========================================

Please check the Jenkins console output
for the failed stage.

==========================================
'''
        }


        always {

            echo '=========================================='
            echo 'Cleaning Jenkins Workspace'
            echo '=========================================='


            sh '''
                echo "Removing local test containers..."

                docker rm -f \
                    test-user-service \
                    test-product-service \
                    test-order-service \
                    2>/dev/null || true


                echo
                echo "Removing test network..."

                docker network rm \
                    microservices-test-network \
                    2>/dev/null || true


                echo
                echo "Removing dangling Docker images..."

                docker image prune -f || true


                echo
                echo "Cleanup completed."
            '''
        }
    }
}
