variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"

}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance"
  type        = string
  default     = "54.234.112.104/32"
}
