variable "my_ip_address" {
    description = "The IP Address of the user deploying the script. Initially a holdover from a lab variable, but can be inserted into security group CIDRs to prevent other IPs from SSHing in."
}
variable "path_to_ssh_public_key" {
    description = "The directory pathway to the public key used for both authentication by Terraform and Ansible. The you.auto.tfvars automatically handles grabbing the public key, with the deployment script automatically generating a key if none exists prior to grabbing."
}
