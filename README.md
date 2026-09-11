# Project 1 — EC2 From Zero

I built an EC2 server with Terraform, then automated it with Python. This
is the foundation project for the series — everything after this builds
on the same pattern: **Terraform provisions the infrastructure, Python
operates it.**

Everything here runs from AWS CloudShell, so you don't need to install
anything locally.

## Architecture

```
AWS
 │
 VPC
 │
 Public Subnet
 │
 EC2 ────────────┬────────────
 │                │
 Security Group   IAM Role
 │                │
 SSH / HTTP       AWS APIs (via SSM)
```

Terraform creates:
- VPC
- Public subnet
- Internet gateway
- Route table
- Security group
- IAM role + instance profile
- EC2 instance
- Elastic IP

Python/boto3 does:
- `list` — show all instances
- `start` — start the instance
- `stop` — stop the instance
- `status` — check the current state
- `terminate` — delete it for good

## Before you start

- An AWS account with permissions to create VPCs, EC2 instances, and IAM
  roles.
- Nothing else — CloudShell has Python, boto3, and AWS credentials
  already set up.
- Stick to availability zones **a, b, c, or d** if you're in `us-east-1`
  — `t3.micro` isn't reliably available in every AZ, and `e`/`f` are the
  ones known to be missing it. If you're using a different region or
  instance type, just check availability first.

## Step 1 — Open AWS CloudShell

1. Log in to the AWS console.
2. In the top right toolbar, click the terminal icon (CloudShell). Expand
   it to full screen — it's easier to work in.
3. You can also just search "CloudShell" in the top search bar.

*(screenshot: `screenshots/01-cloudshell-open.png`)*

## Step 2 — Install Terraform

CloudShell runs Amazon Linux, so we install Terraform through
HashiCorp's yum repo:

```bash
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
```

Check it worked:

```bash
terraform -version
```

*(screenshot: `screenshots/02-terraform-installed.png`)*

## Step 3 — Get the Terraform files onto CloudShell

Clone this repo (or just create the `terraform/` folder yourself and
copy `main.tf`, `variables.tf`, and `outputs.tf` into it):

```bash
git clone <your-repo-url>
cd terraform-boto3-projects/project-1-ec2-from-zero/terraform
```

## Step 4 — Initialize and apply

```bash
terraform init
```

This downloads the AWS provider plugin. Next, see what Terraform is
about to do before it does it:

```bash
terraform plan
```

Read through the plan — it lists every resource it's about to create.
When you're ready:

```bash
terraform apply
```

Type `yes` when prompted. This takes a minute or two.

*(screenshot: `screenshots/03-terraform-apply-output.png`)*

When it finishes, Terraform prints the `instance_id` and `public_ip` —
copy the `instance_id`, you'll need it in the next step.

## Step 5 — Run the Python script

Move up to the project folder and run the manager script:

```bash
cd ..
python3 ec2_manager.py list
```

You should see the instance you just created. Try the rest of the
commands:

```bash
python3 ec2_manager.py status <instance_id>
python3 ec2_manager.py stop <instance_id>
python3 ec2_manager.py start <instance_id>
```

*(screenshot: `screenshots/04-python-script-output.png`)*

## Step 6 — Clean up

EC2 instances and Elastic IPs cost money while they exist. When you're
done experimenting, tear everything down:

```bash
cd terraform
terraform destroy
```

Type `yes` to confirm. This removes every resource Terraform created —
the instance, the VPC, the security group, all of it.

## Adding your screenshots later

1. Create a `screenshots/` folder in this project directory.
2. Save each image there using the filenames referenced above (or your
   own — just update the paths in this README to match).
3. Reference them in Markdown like this:
   ```markdown
   ![CloudShell open](screenshots/01-cloudshell-open.png)
   ```
4. Commit and push — GitHub renders the images automatically wherever
   they're referenced in the README.

## Notes

- If you leave `key_name` blank in `variables.tf`, you can still reach
  the instance through **Session Manager** in the EC2 console (via the
  IAM role) without needing SSH keys or opening port 22 to your IP.
- `allowed_ssh_cidr` defaults to open (`0.0.0.0/0`) for convenience while
  learning. For anything beyond a throwaway project, set it to your own
  IP instead.
