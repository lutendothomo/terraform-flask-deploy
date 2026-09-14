variable "instance_type" {
  description = "EC2 instance type"
  type = string 
  default = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key for SSH access"
  type = string
}

varible "allowed_ssh_cdir" {
  description = "CIDR block allowed to SSH into the instance"
  type = string
  default = "0.0.0.0/0"
}
