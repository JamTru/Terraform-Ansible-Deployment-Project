# COSC2759 Assignment 2

## Student details

- Full Name/Names: **Jamie Truong | Abel John**
- Student ID/IDs: **S3947728 | S3953018**

## Solution design


### Infrastructure


#### Key data flows


### Deployment process


#### Prerequisites


#### Description of the GitHub Actions workflow



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

#### Validating that the app is working



## Contents of this repo
```
.
├── ./.github
│   └── ./.github/workflows
│       └── ./.github/workflows/foo-pipeline.yml
├── ./README.md
├── ./ansible
│   ├── ./ansible/app-playbook.yml
│   ├── ./ansible/database-playbook.yml
│   └── ./ansible/files
│       └── ./ansible/files/snapshot-prod-data.sql
├── ./app
│   ├── ./app/Dockerfile
│   ├── ./app/index.js
│   ├── ./app/package.json
│   └── ./app/views
│       └── ./app/views/pages
│           ├── ./app/views/pages/foos.ejs
│           └── ./app/views/pages/index.ejs
├── ./deploy.sh
├── ./misc
│   ├── ./misc/how-to-build-app-docker-image.txt
│   ├── ./misc/how-to-deploy.txt
│   ├── ./misc/snapshot-prod-data.sql
│   └── ./misc/state-bucket-infra.tf
├── ./output.txrt
├── ./output.txt
└── ./terraform-infra
    ├── ./terraform-infra/deployment.tf
    ├── ./terraform-infra/vars.tf
    └── ./terraform-infra/you.auto.tfvars
```