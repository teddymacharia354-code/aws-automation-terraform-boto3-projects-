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
