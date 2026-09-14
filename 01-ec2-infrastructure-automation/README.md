# Project 1 — Build an EC2 Server with Terraform, Then Automate It with Python

This is the foundation project for this repository.

The goal is to understand what happens when we build a small EC2 environment instead of simply clicking "Launch instance" in the AWS console.

- Terraform will build the infrastructure.
- Python and Boto3 will then operate the EC2 instance.

## What we are building

```
AWS
 |
VPC
 |
Public Subnet
 |
EC2
 /        \
Security Group   IAM Role
 /    \             |
SSH   HTTP        AWS APIs
```

**Terraform creates:**
- VPC
- Public subnet
- Internet Gateway
- Route table
- Security group
- EC2 instance
- IAM role
- IAM instance profile
- Elastic IP

**Python/Boto3 does (interactive menu):**

```
python3 ec2_manager.py
```

Then choose an option:

```
1: list instances
2: stop instance(s)
3: start instance(s)
4: terminate instance(s)
```

---

## Step 1: Log in to AWS and open CloudShell

Log in to your AWS account. At the top of the AWS console, look for the CloudShell terminal icon and open it. You can also search for CloudShell in the AWS search bar.

CloudShell gives us a terminal inside the AWS console, so for this tutorial we can do the project without setting up a local Linux machine first.

## Step 2: Check the AWS CLI

```bash
aws --version
aws configure get region
```

For this project, we will use `us-east-1`.

If no region is returned, set one for the current AWS CLI configuration:

```bash
aws configure set region us-east-1
aws configure get region
```

## Step 3: Install the tools needed for Terraform

```bash
sudo yum install -y yum-utils
```

**What does this do?**
- `yum` is the package manager available in the Amazon Linux environment.
- `install` tells it that we want to install a package.
- `-y` automatically answers yes to the installation prompts.
- `yum-utils` gives us tools such as `yum-config-manager`, which we will use to add the official HashiCorp repository.

Now add the official HashiCorp Amazon Linux repository:

```bash
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
```

Install Terraform:

```bash
sudo yum -y install terraform
terraform version
```

The exact Terraform version may change over time. That is normal.

## Step 4: Check Python and install Boto3

```bash
python3 --version
python3 -m venv .venv
source .venv/bin/activate
pip install boto3
pip show boto3
```

A virtual environment keeps this project's Python packages separate from the rest of the system.

## Step 5: Create the project directory

```bash
mkdir -p ~/terraform-boto3-projects/project-01-ec2-from-zero/terraform
cd ~/terraform-boto3-projects/project-01-ec2-from-zero
cd terraform
```

The final project will look like this:

```
project-01-ec2-infrastructure-automation/
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
```

## Step 6: Create the Terraform provider

Create `provider.tf`.

```hcl
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
```

The provider is the connection between Terraform and AWS. We are not putting AWS access keys in this file. CloudShell already has AWS credentials available through the AWS environment.

## Step 7: Create variables

Create `variables.tf`.

```hcl
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
  default     = "t3.micro"
}

# The name of the EC2 instance

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "terraform-boto3-inst-1"
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
```

Why use variables? Instead of changing the main infrastructure file every time, we can change values such as the region or instance type in one place. For example, another learner might use `eu-west-1` instead of `us-east-1`. They can also choose an Availability Zone available in that region.

## Step 8: Create the VPC and networking

Create `main.tf`.

```hcl
# Create the VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-boto3-vpc"
  }
}


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


# Create the Internet Gateway

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-boto3-igw"
  }
}


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


# Create the security group

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


# Get the latest Amazon Linux 2023 AMI

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


# Create the EC2 instance

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


# Create the Elastic IP

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
```

## Step 9: Create the IAM role and instance profile

Create `iam.tf`.

```hcl
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
```

**IAM role vs instance profile** — this is an important AWS concept.

- The IAM role defines what permissions are available.
- The instance profile is what allows an EC2 instance to receive that role.

That is why the EC2 resource uses `iam_instance_profile = aws_iam_instance_profile.ec2.name`.

## Step 10: Create outputs

Create `outputs.tf`.

```hcl
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
```

## Step 11: Create the variables file

```bash
cp terraform.tfvars.example terraform.tfvars
```

The example file contains the values used for this tutorial. Do not put passwords, AWS secret keys, or private keys in this file.

## Step 12: Initialize Terraform

From the Terraform directory:

```bash
terraform init
```

when you run terraform init, Terraform downloads the providers required by the project. In this project, that means the AWS provider. You should see a successful initialization message.

## Step 13: Format the Terraform code

```bash
terraform fmt
terraform validate
```

You want to see: `Success! The configuration is valid.`

## Step 14: Preview the infrastructure

```bash
terraform plan
```

Terraform now compares the configuration with the current AWS environment and creates a plan. At this point, nothing should be created yet.

## Step 15: Create the infrastructure

```bash
terraform apply
```

Terraform will show the resources it is about to create. Type `yes` when Terraform asks for confirmation.

Terraform should create:
- VPC
- subnet
- Internet Gateway
- route table
- security group
- IAM role
- IAM instance profile
- EC2 instance
- Elastic IP


## Step 16: Check the EC2 instance

```bash
terraform output instance_id
terraform output public_ip
terraform output
```

Open the EC2 console and confirm that the instance is running. Look for the name `terraform-boto3-inst-1`. 

## Step 17: Test the web server

```bash
terraform output website_url
```

Copy the URL into your browser. You should see: `Hello from Terraform and EC2`

This proves that:

```
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
```

## Step 18: Prepare Python/Boto3

```bash
cd ../python
```

Create `requirements.txt`:

```
boto3
```

Install it:

```bash
pip install -r requirements.txt
```

## Step 19: Create the Python EC2 manager

Create `ec2_manager.py`:

```python
import boto3

ec2 = boto3.client('ec2', region_name='us-east-1')

user_option = input('''what command do you wish to run 
1: list instances 
2: stop instance(s) 
3: start instance(s) 
4: terminate instance(s)
''')

if user_option == '1':
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': ['terraformboto3inst1']
            }
        ]
    )
    
   
    instances = [i for r in response['Reservations'] for i in r['Instances']]
    for instance in instances:
        print(f"ID: {instance['InstanceId']}")
        print(f"State: {instance['State']['Name']}")
        

elif user_option == '2':
    instance_id = input("Enter instance ID you wis to stop: ")
    ec2.stop_instances(InstanceIds=[instance_id])
    print(f"{instance_id} SUCCESSFULLY STOPPED")

elif user_option == '3':
    instance_id = input("Enter instance ID you wish to start: ")
    ec2.start_instances(InstanceIds=[instance_id])
    print(f"{instance_id} SUCCESSFULLY STARTED")

elif user_option == '4':
    instance_id = input("Enter instance ID you wish  to terminate: ")
    if input(f"Type yes to delete {instance_id}: ") == 'yes':
        ec2.terminate_instances(InstanceIds=[instance_id])
        print(f"{instance_id} TERMINATED")
```

The program runs as a single interactive script. It uses the AWS credentials available to the CloudShell session.

The EC2 IAM role created by Terraform is attached to the EC2 server itself. It is not automatically the identity used by Python running in CloudShell. 

## Step 20: List EC2 instances with Python

```bash
python3 ec2_manager.py
```

Choose option `1`. The program calls the EC2 API and displays each instance's ID and state.



## Step 21: Stop the instance

```bash
python3 ec2_manager.py
```

Choose option `2`, then enter the instance ID when prompted.

Run option `1` (list) again afterward to confirm the state has changed to `stopping` / `stopped`. Remember that the stop request is asynchronous, so the state may not change immediately.

## Step 22: Start the instance again

```bash
python3 ec2_manager.py
```

Choose option `3`, then enter the instance ID when prompted. Run option `1` again to confirm it returns to `running`.

Because this project uses an Elastic IP, the public IP stays associated with the allocation while the instance is stopped and started.

## Step 23: Terminate the instance

Termination permanently deletes the EC2 instance. The script deliberately asks for confirmation.

```bash
python3 ec2_manager.py
```

Choose option `4`, enter the instance ID, then type `yes` when asked to confirm.

## Step 24: Destroy the Terraform infrastructure

After the EC2 instance has been terminated, return to the Terraform directory:

```bash
cd ../terraform
terraform destroy
```

Terraform will show what it plans to delete. Type `yes`. This removes the infrastructure managed by Terraform.

You should always clean up the project when you are finished to avoid unexpected AWS charges.

---

## Security note

The example SSH rule uses `0.0.0.0/0` because it makes the first tutorial easier to follow. That means SSH is reachable from the internet.

For a real environment, replace it with your own public IP: `YOUR_PUBLIC_IP/32`

