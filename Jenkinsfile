pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '368451698271'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        USER_REPO = "${ECR_REGISTRY}/microservices-devops/user-service"
        PRODUCT_REPO = "${ECR_REGISTRY}/microservices-devops/product-service"
        ORDER_REPO = "${ECR_REGISTRY}/microservices-devops/order-service"

        IMAGE_TAG = "${BUILD_NUMBER}"

        EC2_HOST = '16.176.148.52'
        EC2_USER = 'ubuntu'
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
                    docker --version
                    docker compose version

                    docker compose -f docker-compose.yml config
                    docker compose -f docker-compose.ec2.yml config
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    docker build \
                      -t user-service:${IMAGE_TAG} \
                      ./user-service

                    docker build \
                      -t product-service:${IMAGE_TAG} \
                      ./product-service

                    docker build \
                      -t order-service:${IMAGE_TAG} \
                      ./order-service
                '''
            }
        }

        stage('Test Images') {
            steps {
                sh '''
                    docker run -d \
                      --name user-test \
                      -p 18001:8001 \
                      user-service:${IMAGE_TAG}

                    docker run -d \
                      --name product-test \
                      -p 18002:8002 \
                      product-service:${IMAGE_TAG}

                    docker run -d \
                      --name order-test \
                      -p 18003:8003 \
                      order-service:${IMAGE_TAG}

                    sleep 10

                    curl -f http://localhost:18001/health
                    curl -f http://localhost:18002/health
                    curl -f http://localhost:18003/health
                '''
            }

            post {
                always {
                    sh '''
                        docker rm -f user-test product-test order-test || true
                    '''
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh '''
                    docker tag \
                      user-service:${IMAGE_TAG} \
                      ${USER_REPO}:${IMAGE_TAG}

                    docker tag \
                      product-service:${IMAGE_TAG} \
                      ${PRODUCT_REPO}:${IMAGE_TAG}

                    docker tag \
                      order-service:${IMAGE_TAG} \
                      ${ORDER_REPO}:${IMAGE_TAG}
                '''
            }
        }

        stage('ECR Login') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-ecr-credentials']
                ]) {
                    sh '''
                        aws ecr get-login-password \
                          --region ${AWS_REGION} | \
                        docker login \
                          --username AWS \
                          --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }

        stage('Push Images') {
            steps {
                sh '''
                    docker push ${USER_REPO}:${IMAGE_TAG}
                    docker push ${PRODUCT_REPO}:${IMAGE_TAG}
                    docker push ${ORDER_REPO}:${IMAGE_TAG}
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "mkdir -p ~/microservices-devops/nginx"

                        scp -o StrictHostKeyChecking=no \
                            docker-compose.ec2.yml \
                            ${EC2_USER}@${EC2_HOST}:~/microservices-devops/

                        scp -o StrictHostKeyChecking=no \
                            nginx/nginx.conf \
                            ${EC2_USER}@${EC2_HOST}:~/microservices-devops/nginx/

                        ssh -o StrictHostKeyChecking=no \
                            ${EC2_USER}@${EC2_HOST} \
                            "export USER_IMAGE=${USER_REPO}:${IMAGE_TAG}; \
                             export PRODUCT_IMAGE=${PRODUCT_REPO}:${IMAGE_TAG}; \
                             export ORDER_IMAGE=${ORDER_REPO}:${IMAGE_TAG}; \
                             aws ecr get-login-password \
                             --region ${AWS_REGION} | \
                             docker login \
                             --username AWS \
                             --password-stdin ${ECR_REGISTRY}; \
                             docker pull ${USER_REPO}:${IMAGE_TAG}; \
                             docker pull ${PRODUCT_REPO}:${IMAGE_TAG}; \
                             docker pull ${ORDER_REPO}:${IMAGE_TAG}; \
                             cd ~/microservices-devops; \
                             docker compose -f docker-compose.ec2.yml up -d"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    sleep 15

                    curl -f http://${EC2_HOST}/health
                    curl -f http://${EC2_HOST}/users/
                    curl -f http://${EC2_HOST}/products/
                    curl -f http://${EC2_HOST}/orders/
                '''
            }
        }
    }

    post {
        always {
            sh '''
                docker image prune -f || true
            '''
        }

        success {
            echo 'CI/CD pipeline completed successfully.'
        }

        failure {
            echo 'CI/CD pipeline failed. Check Jenkins console output.'
        }
    }
}
