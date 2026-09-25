# Terraform + Boto3 Projects

A growing collection of hands-on AWS projects. Each one follows the same
pattern: **Terraform provisions the infrastructure, Python (boto3)
operates it.** Every project is a full, working step-by-step tutorial ,
the kind of thing you build once to learn it, then explain to someone
else.

I add a new project whenever I've actually built and understood the next
one ,there's no fixed number planned, this repo just grows over time.

## How this repo is organized

Each project lives in its own folder:

```
terraform-boto3-projects/
├── project-1-ec2-from-zero/
│   ├── terraform_files.tg
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── python_files.py
│   ├── screenshots/
│   └── README.md
├── project-2-.../
│   └── ...
└── README.md  
```

Every project's own `README.md` has the full walkthrough for that
project architecture, setup steps, and how to run it. This top-level
README is just the index.

## Prerequisites

- An AWS account
- AWS CloudShell (no local install needed — Terraform gets installed as
  part of each project's steps, and Python/boto3 are already there)

Some familiarity with the AWS console helps, but each project's README
walks through everything from the first click.

More projects get added as they're built. If you're following along on
YouTube, each project folder corresponds to one video.

## The pattern behind every project

Terraform and boto3 aren't competing tools here — they do different
jobs:

- **Terraform** describes the infrastructure that should exist (the VPC,
  the instance, the IAM role) and keeps it in that state. You run it
  once to build things, and again any time you change the config.
- **Boto3** is for the day-to-day operational stuff . starting and
  stopping resources, checking status, reacting to things — that you
  wouldn't want to express as "infrastructure" in Terraform.

Learning to reach for the right tool for the right job is really the
point of this whole series, more than any individual project.

## License

Feel free to use any of this for your own learning. Attribution
appreciated, not required.
