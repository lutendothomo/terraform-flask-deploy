#!/bin/bash
set -e

# Redirect stdout and stderr to both user-data.log and console
exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "=== Starting user_data bootstrap $(date) ==="

# Wait for unattended-upgrades or cloud-init background apt locks to release
echo "Waiting for background apt locks to release..."
for i in $(seq 1 30); do
    if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
       ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
       ! fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
        break
    fi
    echo "Waiting for background apt lock release (attempt $i/30)..."
    sleep 3
done

export DEBIAN_FRONTEND=noninteractive

# Update package lists with retry
for i in $(seq 1 5); do
    apt-get update -y && break || sleep 5
done

# Install base dependencies with retry
for i in $(seq 1 5); do
    apt-get install -y python3 python3-pip python3-venv git curl && break || sleep 5
done

APP_DIR="/home/ubuntu/app"
mkdir -p "$APP_DIR/app"

# Deploy application code directly from Terraform template
cat > "$APP_DIR/app/app.py" << 'APP_CODE_EOF'
${app_code}
APP_CODE_EOF

cat > "$APP_DIR/app/requirements.txt" << 'REQ_CODE_EOF'
${requirements_code}
REQ_CODE_EOF

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

# Verify service is running and health endpoint returns ok
echo "Verifying Flask application health..."
HEALTHY=0
for i in $(seq 1 15); do
    if curl -sf http://127.0.0.1:5000/health | grep -q '"status":"ok"'; then
        echo "Flask app is live and healthy!"
        HEALTHY=1
        break
    fi
    echo "Waiting for Flask app to respond on port 5000 (attempt $i/15)..."
    sleep 2
done

if [ "$HEALTHY" -ne 1 ]; then
    echo "ERROR: Flask app failed health check!"
    systemctl status flaskapp || true
    journalctl -u flaskapp -n 30 --no-pager || true
    exit 1
fi

echo "=== Completed user_data bootstrap $(date) ==="
