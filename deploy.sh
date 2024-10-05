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

# Check if Private/Public Key exists in Directory.
if [ -f "$path_to_ssh_key" ]; then
    echo "Public key exists: $path_to_ssh_key"
else
    echo "Creating Key Pair at ${path_to_ssh_key}"
    ssh-keygen -C user@SDOa2 -f "${path_to_ssh_key}" -N ''
fi

ip_address=$(curl icanhazip.com)

# Perform Terraform functions to initialise infrastructure
echo "Initialise Terraform"
terraform init
echo "Validating Terraform Configuration"
terraform validate
echo "Applying Terraform Configuration"
terraform apply -var="my_ip_address=$ip_address"

# Define Outputs as Variable
ini_file=$(terraform output ini_file)
app_dns=$(terraform output -raw app_public_hostname)
app_ip=$(terraform output -raw app_public_ip)
db_dns=$(terraform output -raw db_public_hostname)
db_ip=$(terraform output -raw db_public_ip)

# Define Contents of ini file
ini_content="
[app]
app1 ansible_host=${app_dns} app_ip=${app_ip}

[database]
db1 ansible_host=${db_dns} db_ip=${db_ip}
"

# Write the content to the INI file
echo "$ini_content" > $ini_file

# Strip Quotation Marks that result from Terraform Output
# We don't know why it keeps adding quotation marks
mv '"inventory.ini"' inventory.ini
echo "Successfully generated INI file: $ini_file"

# Define Variables for Usage in Ansible
DOCKER_IMAGE_TAG="mattcul/assignment2app:1.0.0"
INI_FILE="terraform-infra/inventory.ini"

# Run Ansible Playbook for Database First
cd ..
echo "Creating Database"
ansible-playbook ansible/database-playbook.yml -i ${INI_FILE}  --private-key "terraform-infra/${path_to_ssh_key}"

# Run Ansible Playbook for Application
ansible-playbook ansible/app-playbook.yml -i ${INI_FILE} -e "app_image=${DOCKER_IMAGE_TAG}" --private-key "terraform-infra/${path_to_ssh_key}"


# Echo Public Application Link
echo "Link to Application: http://${app_ip}"