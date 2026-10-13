#!/bin/bash
set -e

# Redirect stdout and stderr to both user-data.log and console
exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "=== Starting user_data bootstrap $(date) ==="

# Wait for unattended-upgrades or cloud-init apt locks to release
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for background apt lock release..."
    sleep 3
done

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git

APP_DIR="/home/ubuntu/app"

# Clone if not already present, or pull latest if directory exists
if [ ! -d "$APP_DIR" ]; then
    git clone https://github.com/lutendothomo/terraform-flask-deploy.git "$APP_DIR"
else
    cd "$APP_DIR"
    git pull origin main || true
fi

cd "$APP_DIR/app"

# Create virtual environment and install requirements
python3 -m venv venv
venv/bin/pip install --upgrade pip
venv/bin/pip install -r requirements.txt

# Ensure ubuntu user owns all app files and venv
chown -R ubuntu:ubuntu "$APP_DIR"

# Configure systemd service
cat > /etc/systemd/system/flaskapp.service << 'SERVICE'
[Unit]
Description=Flask app
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/app/app
ExecStart=/home/ubuntu/app/app/venv/bin/gunicorn --workers 2 -b 0.0.0.0:5000 --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable flaskapp
systemctl restart flaskapp

echo "=== Completed user_data bootstrap $(date) ==="
