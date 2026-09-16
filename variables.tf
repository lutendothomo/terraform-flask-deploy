variable "instance_type" {
  description = "EC2 instance type"
  type = string 
  default = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance"
  type    = string
  default = "0.0.0.0/0"
}
//he