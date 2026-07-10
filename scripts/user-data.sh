#!/bin/bash
apt update -y
apt install -y python3-pip git
pip3 install flask --break-system-packages

git clone https://github.com/mdshadab41/aws-ha-web-app.git /home/ubuntu/app
cd /home/ubuntu/app/app

nohup python3 app.py > /var/log/flask-app.log 2>&1 &