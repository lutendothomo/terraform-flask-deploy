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

  ingress {
    description = "Flask app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
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
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "terraform-flask-deploy-eip"
  }
}