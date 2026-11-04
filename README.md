# Three Microservices DevOps Project

## Overview

This project demonstrates a DevOps implementation for three sample
microservices:

- User Service
- Product Service
- Order Service

The application is containerized using Docker and Docker Compose.
Nginx is used as a reverse proxy.

## Services

| Service | Port | Health Endpoint |
|---|---:|---|
| User Service | 8001 | /health |
| Product Service | 8002 | /health |
| Order Service | 8003 | /health |
| Nginx | 80 | /health |

## Technologies

- Python
- Flask
- Docker
- Docker Compose
- Nginx
- Git
- GitHub

## Build

docker compose build

## Start

docker compose up -d

## Check

docker compose ps

## Logs

docker compose logs

## Stop

docker compose down

## API Endpoints

User:

http://localhost/users/users

Product:

http://localhost/products/products

Order:

http://localhost/orders/orders

## Health Checks

http://localhost:8001/health
http://localhost:8002/health
http://localhost:8003/health
http://localhost/health

## Architecture

Client
   |
   v
Nginx
   |
   +---- User Service
   |
   +---- Product Service
   |
   +---- Order Service

All containers communicate through the Docker Compose network.

## Security

Secrets, credentials, private keys and local environment files containing
sensitive values must not be committed to Git.

## Future DevOps Stages

Day 2:
Terraform and AWS infrastructure

Day 3:
Jenkins CI/CD and Amazon ECR

Day 4:
Prometheus, Node Exporter, Grafana and troubleshooting


