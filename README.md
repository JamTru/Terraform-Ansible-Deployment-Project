# COSC2759 Assignment 2

## Student details

- Full Name/Names: **Jamie Truong | Abel John**
- Student ID/IDs: **S3947728 | S3953018**

## Contents

- [Summary](#summary)
  - [Tools Used](#tools-used)
- [Deployment](#deployment)
  - [Deploying from Shell Script](#deploying-from-shell-script)
  - [GitHub Actions Workflow](#github-actions-workflow)
- [Infrastructure](#infrastructure)
  - [Terraform](#terraform)
  - [Ansible](#ansible)
- [Diagrams](#diagrams)

## Summary
The solution is designed to accomplish Alpine's business goal of automating their deployment process with greater resiliency by utilising Terraform and Ansible as the primary tools to handle the creation and configuration of the underlying infrastructure the Foo application and database will be hosted on.

The tools are designed such that they will automate the process of provisioning resources and configuring them according to specifications desired by the developer when deploying.

Terraform is responsible for the creation of virtual private cloud along with necessary resources on AWS. It will read a set of configurations pre-written for it, then automatically handle the planning and execution of creating resources based on dependencies without needing human input, thus preventing human error in either the specific configurations of each individual resource or the order of creation of resources.

Ansible is responsible for the configuration of the virtual private cloud resources, by running a defined order of commands to execute according to a `playbook` file. This is done in conjunction with Docker, which containerises the application into an individual image that handles its own dependencies and makes the application system-agnostic in terms of deployment. This thus automates the need to SSH into the individual containers and run all the individual commands, making it far more efficient and eliminates potential for human error.

Furthermore, the only inputs for the solution come from needing the individual deploying the script to confirm changes, such as accepting the initial resource changes from Terraform and confirming the usage of private keys in the EC2 instances. Otherwise, the deployment script automates the need for copy pasting over variables such as IP addresses, docker images, directory locations etc. which eliminates another potential area for human error from the deployment process.

### Tools Used
- GitHub (GitHub Org)
- GitHub Actions – used for creating the pipelines
- Terraform
- Ansible
- AWS
- Docker

## Deployment

#### Deploying from Shell Script

To deploy using the `deploy.sh` shell script, run the following at the root directory of the repository:
```bash
~s3947728-s3953018-assignment-2# bash deploy.sh
```

The deployment shell script will handle the following tasks in this sequence:

1. Validate the User's AWS Credentials and ensure they exist.
    > Note: This does not ensure that the `.aws/credentials` will match the cloud that the EC2 instances deploy in. Please ensure that credentials are updated.
2. Ensure public/private key pair exists within the `./terraform-infra` directory.
    > Note: If the script does not detect that a `local_pub_key` exists within the directory, it will generate one for you. This is hidden by the `.gitignore` file for security reasons.
3. Initialise, validate and execute Terraform files.
    > Note: Refer to Terraform section for in-depth explanation of `deployment.tf`.
4. Save the output of Terraform as variables, as well as writing it to a `.ini` file.
    > Note: At this stage, the EC2 instances' public IP address and DNS are saved. They are then also written into the `inventory.ini` to be used as inventory files for Ansible. Additionally, the `"inventory.ini"` file is renamed to 'inventory.ini' file for formatting reasons. It is not quite understood why it is initially outputted as `"inventory.ini"` by Terraform, but the step is necessary so Ansible can read it.
5. Initialise the Database Container using Terraform outputs through Ansible.
    > Note: Refer to Ansible section for in-depth explanation of Ansible playbook structure. Ansible command takes input of `inventory.ini` file to have access to EC2 instance IP addresses, and reuses the same private key defined earlier within bash script.
6. Initialise the Application Container using Terraform ouputs through Ansible.
    > Note: Refer to Ansible Section for in-depth explanation of Ansible playbook structure. To avoid any possible issues with dependencies, the application is initialised after the database is initialised to avoid any problems with the application needing to make a connection before a database exists.
7.  Echo HTTP Link to Application
    > Note: This is purely for debugging purposes as it provides an easy method of accessing application from terminal.

#### GitHub Actions Workflow


## Infrastructure
### Terraform


### Ansible


## Diagrams
