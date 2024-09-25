#!/bin/bash
#
# Deploy Foo app - see README.md
#
# Bash Script is partially adapted from Week 7 and 8 Lab Scripts

set -e # Bail When Error Detected
echo "Now Beginning Assignment 2 Deployment Script"
echo "Testing AWS Credentials"
aws sts get-caller-identity

# Generate brand new key for user

cd terraform-infra
path_to_ssh_key="local_pub_key"
echo "Creating Key Pair at ${path_to_ssh_key}"
ssh-keygen -C user@SDOa2 -f "${path_to_ssh_key}" -N ''
ip_address=$(curl icanhazip.com)

echo "Initialise Terraform"
terraform init
echo "Validating Terraform Configuration"
terraform validate
echo "Applying Terraform Configuration"
terraform apply -var="my_ip_address=$ip_address"


app_dns=$(terraform output -raw app_public_hostname)
app_ip=$(terraform output -raw app_public_ip)
db_dns=$(terraform output -raw db_public_hostname)
db_ip=$(terraform output -raw db_public_ip)

# Build Docker Image
DOCKER_IMAGE_TAG="mattcul/assignment2app:1.0.0"
DOCKERFILE_PATH="./app/Dockerfile"
docker buildx build --platform linux/amd64,linux/arm64 -t ${DOCKER_IMAGE_TAG} -f ${DOCKERFILE_PATH} . --push
