# terraform-flask-deploy

Infrastructure-as-code deployment of a Flask app to AWS, with an automated
CI/CD pipeline via GitHub Actions.

## Status
- [x] Terraform provider configured
- [ ] Core infrastructure (compute, networking)
- [ ] GitHub Actions pipeline (lint/test -> plan -> apply)
- [ ] Monitoring and auto-scaling


## Deploying

```bash
terraform init
terraform apply -var="key_name=<your-key-pair-name>"
terraform output instance_public_ip
curl http://<that-ip>:5000/
curl http://<that-ip>:5000/health
```

Run `terraform destroy` when you're done testing to avoid leaving the
instance running idle.
