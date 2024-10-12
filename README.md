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

![Deployment Bash Script Processes](misc/process_diagram.svg)

#### GitHub Actions Workflow
![Github Actions Deployment Pipeline](https://github.com/user-attachments/assets/434cc206-1cce-4fbd-b437-2350bc683ee7)

The Foo Pipeline automates the deployment process by executing a series of jobs in a specific order. It can be triggered by:
- Push to main branch: When someone pushes code to the main branch of the associated repository.
- An API call posted to `https://api.github.com/repos/S3947728/s3947728-s3953018-assignment-2
/actions/workflows/WORKFLOW_ID/dispatches` with the request body containing `event_type: deploy_foo`

The pipeline consists of two main jobs:
- validate-credentials
- deploy-infra

> validate-credentials
- The validate-credentials job in this GitHub Actions workflow is primarily responsible for ensuring that the necessary AWS credentials are correctly configured and accessible within the pipeline.
- 1. Checkout Code: This step fetches the required code from the GitHub repository where the workflow is defined. This code might contain additional configuration or scripts necessary for the validation process.
  2. Debug AWS Secrets: This step checks if the following AWS secrets are defined and non-empty:
```
AWS_SECRET_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```
  3. Set Up AWS CLI: This step configures the AWS Command-Line Interface (CLI) tool with the retrieved AWS credentials.
  4. Test AWS Credentials: This step runs the aws sts get-caller-identity command to verify the validity of the configured AWS credentials.


> deploy-infra
- The deploy-infra job in this GitHub Actions workflow is responsible for deploying the infrastructure and application on AWS. This job depends on the successful completion of the validate-credentials, to ensure that the deployment step doesn't fire if there are no secrets set up within the Repository. Note that the prior step does not validate the credentials are necessarily the same as the ones needed to SSH into the instances.
  1. Setting Up the Environment:
     - Checkout Code: Fetches the necessary code from the GitHub repository.
     - Configure AWS CLI: Sets up the AWS CLI tool with credentials retrieved from the GitHub Secrets
     - Get Public IP Address: Retrieves the public IP address of the runner machine
     - Create SSH Public Key File: Creates a file named local_pub_key.pub in the ./terraform-infra from pre-existing key in Secrets.
     - Setup Terraform: Installs the Terraform CLI tool in the runner environment.
  2. Run Terraform
     -  Initialize Terraform: Initializes the Terraform
     -  Validate Terraform: Runs the terraform validate command to check for any errors or syntax issues
     -  Terraform Plan: Creates a plan for the infrastructure deployment using the terraform plan
     -  Terraform Apply: Executes the terraform apply command
     -  Display Outputs: Retrieves information about the deployed resources using Terraform outputs. These outputs are stored an INI file for later use.
  3. Run Ansible
     - Database Playbook: Executes the database playbook
     - Application Playbook: Executes the application playbook

- Notably, the pipeline will always execute, but the tools themselves will already handle the idempotency of the deployment as it will always validate and recheck if the state has changed. This is known due to Terraform Plan command that outputs detection of different states, as well as the Ansible step using the `[ok]` response instead of the `[changed]` response to indicate updates have been made.

## Infrastructure
### Terraform
![AWS Infrastructure Generated by Terraform](https://github.com/user-attachments/assets/1f515390-07d4-44a8-887b-144234f1adf9)

> VPC and Subnets
- Creates a VPC with CIDR block 10.0.0.0/16
- Defines two public subnets (10.0.1.0/24 and 10.0.2.0/24) across two Availability Zones (us-east-1a and us-east-1b) for deploying the application instances.
- Has been configured with `enable_dns_support = true` and `enable_dns_hostnames = true` to allow for the EC2 instances to have public DNS names.
- The subnets contain the setting `map_public_ip_on_launch = true` to ensure that EC2 instances deployed inside the subnet will always have a public IP address to reference.

> Security Groups
- 2 Security groups are created for both app and database instances
Both security groups are open on:
- Port 22: For Ansible to be able to SSH in to configure the instances
- Port 80: To allow users to access the application through the IP address provided.
- Port 5432: To allow for the instances to communicate to each other and access / transfer information from the database instance.

> Application Instances
- 2 Application Instances using `t.2 micro` instance type launched in two different public subnets
- `associate_public_ip_address = true` setting is made explicit to ensure that the EC2 has a public IP address associated with it within the VPC

> Load Balancer
- Distribute traffic across the two application instances

> Database Instance
- Creates a single database instance using the same `t2.micro instance` type with the same AMI as the application instances
- Launches the database instance in a public subnet

S3
- The S3 backend configuration in Terraform allows to the state file in an Amazon S3 bucket, enabling centralized management, versioning, and security.

### Ansible

The Ansible aspect of the solution is designed to automate the configuration of the EC2 instances by remotely connecting into the EC2 instances set up and outputted by Terraform via SSH. To accomplish this, an INI file is generated by Terraform that is split into the following:
```
[app]
app1 ansible_host=${app1_dns} app_ip=${app1_ip}
app2 ansible_host=${app2_dns} app_ip=${app2_ip}

[database]
db1 ansible_host=${db_dns} db_ip=${db_ip}
```
where `[app]` represents the number of app instances generated by Terraform, whereas `[database]` represents the number of database instances generated by Terraform. The decision to use INI files over YAML Playbooks was due to the ability to customise and insert variables into INI files that was absent from the playbooks. Thus YAML playbooks was incompatible with the automation due to the constant changing of IP addresses when generating new EC2 instances.

> Playbook Breakdown

The steps of the Application Playbook is as follows:
1. Retrieve and Install Docker
2. Pull Docker Image
3. Create Docker Container
The playbook was written so that the Docker Image is a variable passed through as a command to allow for flexibility, allowing any future modifications to simply change the docker image needed to be passed through. As well, to allow the application instance to be granted database access, it is configured the ENV variables with the database instance IP address and the login/password of database user.

For the database instance, the Database Playbook follows these steps:
1. Retrieve and Install Docker
2. Pull Postgres Docker Image
3. Copy SQL file from local to instance
4. Create Postgres Container with data mounted

As it is unlikely for the database to change as often as the application's docker image, it was decided to hard-code the Postgres image into the playbook for convenience. Additionally, it was necessary to directly copy the SQL file into the EC2 instance as it then allowed for the mounting of the SQL as a volume and thus set up the database on deployment before any applications need to access it.

Additionally, Ansible by default searches for files to copy from the directory it is executed in, within the subdirectory `/files`, and as such, it was easier to copy over the SQL into the `ansible/files` directory to make it easier to retrieve.
