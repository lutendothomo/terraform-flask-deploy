#!/bin/bash
set -e
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git

cd /home/ubuntu
git clone https://github.com/lutendothomo/terraform-flask-deploy.git app
cd app/app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cat > /etc/systemd/system/flaskapp.service << 'SERVICE'
[Unit]
Description=Flask app
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app/app
ExecStart=/home/ubuntu/app/app/venv/bin/gunicorn -b 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable flaskapp
systemctl start flaskapp
