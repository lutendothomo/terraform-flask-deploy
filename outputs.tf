output "instance_public_ip" {
  description = "Public IP of the app server"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "Public URL of the Flask application"
  value       = "http://${aws_instance.app.public_ip}:5000"
}

output "ssh_private_key" {
  description = "SSH private key for the Terraform-managed deploy key pair (sensitive). Extract with: terraform output -raw ssh_private_key > ~/.ssh/tf_flask_key && chmod 600 ~/.ssh/tf_flask_key"
  value       = tls_private_key.deploy_key.private_key_openssh
  sensitive   = true
}
