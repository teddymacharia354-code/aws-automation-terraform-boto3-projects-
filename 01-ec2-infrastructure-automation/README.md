Project 1 — Build an EC2 Server with Terraform, Then Automat It with Python
This is the foundation project for this repository.
The goal is to understand what happens when we build a small EC2 environment instead of simply clicking "Launch instance" in the AWS console.
Terraform will build the infrastructure.
Python and Boto3 will then operate the EC2 instance.
What we are building
AWS
                          |
                         VPC
                          |
                    Public Subnet
                          |
                         EC2
                    /           \
           Security Group     IAM Role
             /      \             |
           SSH      HTTP        AWS APIs
Terraform creates:
VPC
Public subnet
Internet Gateway
Route table
Security group
EC2 instance
IAM role
IAM instance profile
Elastic IP
Python/Boto3 does:
python3 ec2_manager.py list
python3 ec2_manager.py start <instance_id>
python3 ec2_manager.py stop <instance_id>
python3 ec2_manager.py status <instance_id>
python3 ec2_manager.py terminate <instance_id>
Step 1: Log in to AWS and open CloudShell
Log in to your AWS account.
At the top of the AWS console, look for the CloudShell terminal icon and open it.
You can also search for CloudShell in the AWS search bar.
CloudShell gives us a terminal inside the AWS console, so for this tutorial we can do the project without setting up a local Linux machine first.
Step 2: Check the AWS CLI
CloudShell normally includes the AWS CLI.
Run:
aws --version
Then check which region your CloudShell session is using:
aws configure get region
For this project, we will use:
us-east-1
If no region is returned, you can set one for the current AWS CLI configuration:
aws configure set region us-east-1
Check it again:
aws configure get region
Step 3: Install the tools needed for Terraform
We first install yum-utils.
sudo yum install -y yum-utils
What does this do?
yum is the package manager available in the Amazon Linux environment.
install tells it that we want to install a package.
-y automatically answers yes to the installation prompts.
yum-utils gives us tools such as yum-config-manager, which we will use to add the official HashiCorp repository.
Now add the official HashiCorp Amazon Linux repository:
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
Install Terraform:
sudo yum -y install terraform
Check the installation:
terraform version
The exact Terraform version may change over time. That is normal.
Step 4: Check Python and install Boto3
Check Python:
python3 --version
Create a small virtual environment for the Python part of the project:
python3 -m venv .venv
Activate it:
source .venv/bin/activate
Install Boto3:
pip install boto3
Check that it installed:
pip show boto3
Why are we using a virtual environment?
It keeps this project's Python packages separate from the rest of the system.
Step 5: Create the project directory
Create a directory for the project:
mkdir -p ~/terraform-boto3-projects/project-01-ec2-from-zero/terraform
Move into it:
cd ~/terraform-boto3-projects/project-01-ec2-from-zero
Create the Python directory:
mkdir -p python screenshots
Move into the Terraform directory:
cd terraform
The final project will look like this:
project-01-ec2-from-zero/
|
|-- terraform/
|   |-- provider.tf
|   |-- variables.tf
|   |-- main.tf
|   |-- iam.tf
|   |-- outputs.tf
|   `-- terraform.tfvars.example
|
|-- python/
|   |-- ec2_manager.py
|   `-- requirements.txt
|
`-- screenshots/
Step 6: Create the Terraform provider
Create provider.tf.
# Tell Terraform that this project will use the AWS provider

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Tell the AWS provider which region to use

provider "aws" {
  region = var.aws_region
}
The provider is the connection between Terraform and AWS.
We are not putting AWS access keys in this file.
CloudShell already has AWS credentials available through the AWS environment.
Step 7: Create variables
Create variables.tf.
# The AWS region where we will build the project

variable "aws_region" {
  description = "AWS region for the project"
  type        = string
  default     = "us-east-1"
}

# The Availability Zone for our public subnet

variable "availability_zone" {
  description = "Availability Zone for the public subnet"
  type        = string
  default     = "us-east-1a"
}

# The EC2 instance type

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# The name of the EC2 instance

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "terraform-boto3-ec2"
}

# The EC2 key pair name.
#
# Create a key pair in the EC2 console first if you want SSH access.
# If you do not need SSH for this lesson, you can leave this empty.

variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
  default     = ""
}

# CIDR allowed to connect using SSH.
#
# For learning, 0.0.0.0/0 is simple, but it exposes SSH to the internet.
# For real environments, use your own public IP followed by /32.

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to connect to SSH"
  type        = string
  default     = "0.0.0.0/0"
}
Why use variables?
Instead of changing the main infrastructure file every time, we can change values such as the region or instance type in one place.
For example, another learner might use:
eu-west-1
instead of:
us-east-1
They can also choose an Availability Zone available in that region.
Step 8: Create the VPC and networking
Create main.tf.
# -------------------------------
# VPC
# -------------------------------

# Create the main VPC for our project

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-boto3-vpc"
  }
}


# -------------------------------
# Public Subnet
# -------------------------------

# Create a subnet inside the VPC

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-boto3-public-subnet"
  }
}


# -------------------------------
# Internet Gateway
# -------------------------------

# The Internet Gateway allows the VPC to communicate
# with the public internet.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-boto3-igw"
  }
}


# -------------------------------
# Route Table
# -------------------------------

# Create a route table for the public subnet

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Send internet traffic to the Internet Gateway

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "terraform-boto3-public-route-table"
  }
}


# Connect the public subnet to the route table

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# -------------------------------
# Security Group
# -------------------------------

# A security group acts like a firewall for our EC2 instance.

resource "aws_security_group" "ec2" {
  name        = "terraform-boto3-ec2-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  # Allow SSH

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Allow HTTP

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow the EC2 instance to send traffic out.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-boto3-ec2-sg"
  }
}


# -------------------------------
# Latest Amazon Linux 2023 AMI
# -------------------------------

# AWS publishes the current Amazon Linux AMI through SSM Parameter Store.
# Terraform reads the parameter instead of us hardcoding an AMI ID.

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


# -------------------------------
# EC2 Instance
# -------------------------------

# Create the EC2 server

resource "aws_instance" "web" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = var.instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  # Only send a key pair to EC2 when one was provided.

  key_name = var.key_name != "" ? var.key_name : null

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF
              #!/bin/bash

              # Update installed packages

              dnf update -y

              # Install a simple web server

              dnf install -y httpd

              # Start Apache

              systemctl enable httpd
              systemctl start httpd

              # Create a simple page

              echo "<h1>Hello from Terraform and EC2</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}


# -------------------------------
# Elastic IP
# -------------------------------

# Give the EC2 instance a stable public IPv4 address

resource "aws_eip" "web" {
  domain = "vpc"

  tags = {
    Name = "terraform-boto3-eip"
  }
}


# Attach the Elastic IP to the EC2 instance

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}
Step 9: Create the IAM role and instance profile
Create iam.tf.
# The IAM role allows AWS services to act on behalf of the EC2 instance.

resource "aws_iam_role" "ec2" {
  name = "terraform-boto3-ec2-role"

  # This policy says that EC2 is allowed to use this role.

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "terraform-boto3-ec2-role"
  }
}


# Attach the AWS Systems Manager policy.
#
# This allows the instance to work with Systems Manager.
# We will not use SSM as the main part of this project,
# but it gives the instance a useful AWS service role.

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# An instance profile is the container that lets EC2 use the IAM role.

resource "aws_iam_instance_profile" "ec2" {
  name = "terraform-boto3-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "terraform-boto3-ec2-profile"
  }
}
IAM role vs instance profile
This is an important AWS concept.
The IAM role defines what permissions are available.
The instance profile is what allows an EC2 instance to receive that role.
That is why the EC2 resource uses:
iam_instance_profile = aws_iam_instance_profile.ec2.name
Step 10: Create outputs
Create outputs.tf.
# Show the VPC ID after Terraform finishes

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}


# Show the subnet ID

output "subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}


# Show the EC2 instance ID

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}


# Show the public IP address

output "public_ip" {
  description = "The Elastic IP address"
  value       = aws_eip.web.public_ip
}


# Show the URL that we can open in a browser

output "website_url" {
  description = "The web server URL"
  value       = "http://${aws_eip.web.public_ip}"
}


# Show the IAM role name

output "iam_role_name" {
  description = "The IAM role attached to EC2"
  value       = aws_iam_role.ec2.name
}
Step 11: Create the variables file
Copy the example file:
cp terraform.tfvars.example terraform.tfvars
The example file contains the values used for this tutorial.
Do not put passwords, AWS secret keys, or private keys in this file.
Step 12: Initialize Terraform
From the Terraform directory:
terraform init
What does terraform init do?
Terraform downloads the providers required by the project.
In this project, that means the AWS provider.
You should see a successful initialization message.
Step 13: Format the Terraform code
Run:
terraform fmt
This makes the Terraform formatting consistent.
Then check the configuration:
terraform validate
You want to see:
Success! The configuration is valid.
Step 14: Preview the infrastructure
Run:
terraform plan
Terraform now compares the configuration with the current AWS environment and creates a plan.
At this point, nothing should be created yet.
This is a good screenshot for the video and GitHub repository.
Save it as:
screenshots/02-terraform-plan.png
Step 15: Create the infrastructure
Run:
terraform apply
Terraform will show the resources it is about to create.
Type:
yes
when Terraform asks for confirmation.
Terraform should create:
VPC
subnet
Internet Gateway
route table
security group
IAM role
IAM instance profile
EC2 instance
Elastic IP
When it finishes, Terraform will print the outputs.
Take a screenshot.
Suggested filename:
screenshots/03-terraform-apply.png
Step 16: Check the EC2 instance
Run:
terraform output instance_id
Then:
terraform output public_ip
You can also run:
terraform output
Open the EC2 console and confirm that the instance is running.
Look for the name:
terraform-boto3-ec2
Take a screenshot.
Step 17: Test the web server
Get the website URL:
terraform output website_url
Copy the URL into your browser.
You should see:
Hello from Terraform and EC2
This proves that:
Internet
   |
Internet Gateway
   |
Route Table
   |
Public Subnet
   |
Security Group
   |
EC2
   |
Apache
is working.
Take a screenshot for the repository.
Suggested filename:
screenshots/04-ec2-web-page.png
Step 18: Prepare Python/Boto3
Move into the Python directory:
cd ../python
Create requirements.txt:
boto3
Install it:
pip install -r requirements.txt
Step 19: Create the Python EC2 manager
Create:
ec2_manager.py
Use the code in this repository.
The program provides five commands:
python3 ec2_manager.py list
python3 ec2_manager.py start <instance_id>
python3 ec2_manager.py stop <instance_id>
python3 ec2_manager.py status <instance_id>
python3 ec2_manager.py terminate <instance_id>
The Python program uses the AWS credentials available to the CloudShell session.
The EC2 IAM role created by Terraform is attached to the EC2 server itself. It is not automatically the identity used by Python running in CloudShell.
This is an important distinction to explain in the video.
Step 20: List EC2 instances with Python
Run:
python3 ec2_manager.py list
The program calls the EC2 API and displays:
Name
Instance ID
State
Instance type
Public IP
Take a screenshot.
Suggested filename:
screenshots/07-python-list.png
Step 21: Check the instance status
First get the instance ID:
terraform output instance_id
Then run:
python3 ec2_manager.py status YOUR_INSTANCE_ID
For example:
python3 ec2_manager.py status i-0123456789abcdef0
You should see something similar to:
Instance i-0123456789abcdef0 is currently: [RUNNING]
Take a screenshot.
Step 22: Stop the instance
Run:
python3 ec2_manager.py stop YOUR_INSTANCE_ID
Then check the status:
python3 ec2_manager.py status YOUR_INSTANCE_ID
The state should eventually become:
STOPPED
Remember that the stop request is asynchronous, so the status may not change immediately.
Step 23: Start the instance again
Run:
python3 ec2_manager.py start YOUR_INSTANCE_ID
Then:
python3 ec2_manager.py status YOUR_INSTANCE_ID
The instance should eventually return to:
RUNNING
Because this project uses an Elastic IP, the public IP stays associated with the allocation while the instance is stopped and started.
Step 24: Terminate the instance
Termination permanently deletes the EC2 instance.
The Python script deliberately asks for confirmation.
Run:
python3 ec2_manager.py terminate YOUR_INSTANCE_ID
When asked:
Are you SURE you want to terminate ...? (yes/no):
type:
yes
The instance will be sent a termination request.
Step 25: Destroy the Terraform infrastructure
After the EC2 instance has been terminated, return to the Terraform directory:
cd ../terraform
Run:
terraform destroy
Terraform will show what it plans to delete.
Type:
yes
This removes the infrastructure managed by Terraform.
You should always clean up the project when you are finished to avoid unexpected AWS charges.
Important note about Terraform state
Terraform creates a local state file:
terraform.tfstate
Do not upload this file to GitHub.
The .gitignore in the project excludes Terraform state and other local files.
Availability Zones
The walkthrough uses:
us-east-1a
because the project is being demonstrated in us-east-1.
For this project, the walkthrough can use:
us-east-1a
us-east-1b
us-east-1c
us-east-1d
Do not use us-east-1e or us-east-1f for this specific walkthrough.
For other learners, the guide should not claim that these letters exist in every AWS region. Availability Zones are region-specific and can differ between AWS accounts.
If someone uses another region, they should choose an Availability Zone that actually exists and is available to their account.
Instance type
This tutorial defaults to:
t2.micro
The important lesson is not the specific instance type.
If a learner's region or account does not offer t2.micro, they should choose a small instance type available to their account and adjust instance_type.
Always check current AWS pricing and Free Tier eligibility before creating resources.
Security note
The example SSH rule uses:
0.0.0.0/0
because it makes the first tutorial easier to follow.
That means SSH is reachable from the internet.
For a real environment, replace it with your own public IP:
YOUR_PUBLIC_IP/32
Do not copy the tutorial's open SSH rule into production systems without understanding the risk.
Video flow
A clean YouTube walkthrough can follow this order:
Introduce the architecture.
Open AWS CloudShell.
Check AWS CLI.
Install Terraform.
Create the project folders.
Explain the Terraform files.
Run terraform init.
Run terraform fmt.
Run terraform validate.
Run terraform plan.
Run terraform apply.
Show the AWS resources.
Open the web server.
Explain the IAM role and instance profile.
Install Boto3.
Explain ec2_manager.py.
Run list.
Run status.
Run stop.
Run start.
Run terminate.
Run terraform destroy.
Explain what the learner built.
The repository is designed so that viewers can follow along while watching the video.
