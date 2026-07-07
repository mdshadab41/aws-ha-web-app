#!/bin/bash
yum update -y
yum install -y python3 git
pip3 install flask

git clone https://github.com/<your-username>/aws-ha-web-app.git /home/ec2-user/app
cd /home/ec2-user/app/app

nohup python3 app.py > /var/log/flask-app.log 2>&1 &