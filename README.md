# terraform-flask-deploy

A Flask app deployed to AWS EC2 using Terraform, with a GitHub Actions
CI/CD pipeline that validates, plans, and applies infrastructure changes
automatically. Terraform state is stored remotely in S3 so infrastructure
stays consistent across CI runs.

## Project structure

```
terraform-flask-deploy/
├── .github/
│   └── workflows/
│       └── ci.yml            # CI/CD pipeline: validate -> plan -> apply
├── app/
│   ├── app.py                 # Flask application
│   └── requirements.txt       # Python dependencies (Flask, gunicorn)
├── scripts/
│   └── user_data.sh           # EC2 bootstrap script (installs deps, starts app as a systemd service)
├── main.tf                    # Terraform + provider + S3 backend config
├── variables.tf                # Input variables (region, instance_type, allowed_ssh_cidr)
├── ec2.tf                      # Key pair, security group, EC2 instance, CloudWatch alarm
├── outputs.tf                  # Outputs: instance_public_ip, ssh_private_key
├── .gitignore                  # Excludes *.pem, *.tfstate, .terraform/
└── README.md
```

## Architecture

Terraform provisions:

- **EC2 instance** (`t3.micro`, Ubuntu 22.04) running the Flask app via
  `gunicorn`, bootstrapped with `scripts/user_data.sh`

- **Security group** (`flask-app-sg`) allowing:
  - SSH (port 22) from a single restricted IP (`var.allowed_ssh_cidr`)
  - App traffic (port 5000) from anywhere
- **Auto-generated SSH key pair** (`flask-deploy-key-tf`, via the `tls`
  provider) — no manual key upload needed; the private key is available
  as a sensitive Terraform output
- **CloudWatch alarm** (`flask-app-status-check-failed`) that triggers
  if the instance fails an AWS status check

Terraform state is stored remotely in an **S3 bucket**, not on disk —
this matters because GitHub Actions runners are ephemeral (destroyed
after every job), so local state would be lost between runs and cause
Terraform to try recreating resources that already exist.

## Prerequisites (one-time setup)

### 1. IAM user for CI

Create an IAM user (e.g. `github-actions-terraform`) with programmatic
access only, and attach:
- `AmazonEC2FullAccess` — to create/manage the instance, security
  group, and key pair
- `AmazonS3FullAccess` — to read/write Terraform state in the backend
  bucket

Generate an access key for this user (Security credentials tab →
Create access key → CLI use case).

### 2. S3 bucket for remote state

```bash
aws s3api create-bucket --bucket <your-unique-bucket-name> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-unique-bucket-name> --versioning-configuration Status=Enabled
```

Bucket names are globally unique across all AWS accounts, so pick
something specific (e.g. `<yourname>-tfstate-flaskdeploy`).

Reference this bucket in the `backend "s3"` block in `main.tf`.

### 3. GitHub repo secrets

Under **Settings → Secrets and variables → Actions**, add:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

(values from the IAM user created in step 1)

## CI/CD pipeline (`.github/workflows/ci.yml`)

Three jobs:

1. **`validate`** — runs on every push and pull request. Checks
   `terraform fmt`, runs `terraform init -backend=false` (syntax-only,
   no AWS/S3 access needed), and `terraform validate`.
2. **`plan`** — runs only on pull requests. Initializes against the
   real S3 backend and shows the proposed infrastructure diff before
   merging.
3. **`apply`** — runs only on a direct push to `main`. Initializes
   against the S3 backend and actually provisions/updates the
   infrastructure.

## Deploying manually (local machine)

```bash
terraform init
terraform plan
terraform apply
```

Get the app's public address:

```bash
terraform output instance_public_ip
```

Then visit `http://<that-ip>:5000`.

SSH in (only works if your current IP matches `allowed_ssh_cidr` in
`variables.tf` — update it if your IP has changed):

```bash
terraform output -raw ssh_private_key > tf_key.pem
chmod 600 tf_key.pem
ssh -i tf_key.pem ubuntu@$(terraform output -raw instance_public_ip)
```

## Tearing down

```bash
terraform destroy
```



## Known limitations

- `allowed_ssh_cidr` must be updated manually if your IP changes
  (e.g. switching networks); it does not auto-detect your current IP.
- The Flask app is served over plain HTTP on port 5000 — no TLS/HTTPS
  is configured.
- The app itself has no persistent database; any data created while
  the instance is running is lost on `terraform destroy` or instance
  replacement.
- No automated `terraform destroy` workflow exists yet — teardown is a
  manual step.
- No state-locking table (e.g. DynamoDB) is configured yet, so two
  simultaneous `apply` runs could in theory race and corrupt state.
  Low risk for a solo project, but worth noting.

## Troubleshooting notes (from real issues hit during development)

- **`InvalidGroup.Duplicate` / `InvalidKeyPair.Duplicate` on `apply`**
  — means Terraform's state doesn't match what's actually in AWS
  (usually because state was local and got lost when a CI runner was
  destroyed). Fix: ensure the S3 backend is configured, and manually
  delete any orphaned AWS resources that don't exist in the current
  state before re-applying.
- **`403 Forbidden` reading state from S3** — the IAM user lacks S3
  permissions; attach `AmazonS3FullAccess` (or a scoped equivalent).
- **`Error: Value for undeclared variable`** — a `-var` flag was
  passed in CI for a variable not declared in `variables.tf`, or vice
  versa. Keep the two in sync.
- **`terraform fmt -check` failing** — run `terraform fmt -recursive`
  locally and commit the result.