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


ini_file=$(terraform output ini_file)

app_dns=$(terraform output -raw app_public_hostname)
app_ip=$(terraform output -raw app_public_ip)
db_dns=$(terraform output -raw db_public_hostname)
db_ip=$(terraform output -raw db_public_ip)

ini_content="
[app]
hostname = ${app_dns}
ip = ${app_ip}

[database]
hostname = ${db_dns}
ip = ${db_ip}
"

# Write the content to the INI file
echo "$ini_content" > "$ini_file"

echo "Successfully generated INI file: $ini_file"

# FOR ABEL
# MODIFY TERRAFORM TO OUTPUT AN .ini FILE CONTAINING THE DIFFERENT IPs
# USE .ini FILE AS INVENTORY FILE
# https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ini_inventory.html


DOCKER_IMAGE_TAG="mattcul/assignment2app:1.0.0"
DOCKERFILE_PATH="../app/Dockerfile"

# Run Ansible Playbook for Database First
cd ../ansible
echo "Creating Database"
ansible-playbook database-playbook.yml -e "db_ip=${db_ip}" --private-key ../terraform-infra/${path_to_ssh_key}

# Run Ansible Playbook for Application
ansible-playbook app-playbook.yml -e "app_ip=${app_ip}" --private-key ../terraform-infra/${path_to_ssh_key}