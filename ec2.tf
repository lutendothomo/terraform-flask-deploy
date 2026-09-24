data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
resource "aws_security_group" "app_sg" {
  name        = "flask-app-sg"
  description = "Allow SSH and app traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  # This is a public web app on port 5000 -- open ingress here is the
  # intended design, not an oversight. SSH above stays locked to a
  # single IP via var.allowed_ssh_cidr.
  ingress {
    description = "Flask app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # tfsec:ignore:aws-ec2-no-public-egress-sgr
  # Outbound internet is required for user_data.sh (apt-get, git clone,
  # pip install) to bootstrap the instance on first boot.
  egress {
    description = "Allow all outbound traffic (required for apt/git/pip during bootstrap)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deploy_key" {
  key_name   = "flask-deploy-key-tf"
  public_key = tls_private_key.deploy_key.public_key_openssh
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data              = file("${path.module}/scripts/user_data.sh")

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "terraform-flask-deploy"
  }
}
resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "flask-app-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers if the instance fails an AWS status check"

  dimensions = {
    InstanceId = aws_instance.app.id
  }
}