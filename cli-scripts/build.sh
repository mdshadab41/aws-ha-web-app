#!/bin/bash
# AWS Highly Available Web App — CLI Build Script
# Region: ap-south-1
# This recreates the same architecture as the console version, using AWS CLI.
# Run each section in order. Variables are captured as you go since later
# steps depend on IDs returned by earlier ones.

# ---------------------------------------------------------------------------
# 1. VPC
# ---------------------------------------------------------------------------
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text)
echo "VPC_ID=$VPC_ID"

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=aws-ha-web-app-vpc-cli

# ---------------------------------------------------------------------------
# 2. Subnets (2 public, 2 private, paired by AZ)
# ---------------------------------------------------------------------------
PUBLIC_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a --query 'Subnet.SubnetId' --output text)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1b --query 'Subnet.SubnetId' --output text)
PRIVATE_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 \
  --availability-zone ap-south-1a --query 'Subnet.SubnetId' --output text)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 \
  --availability-zone ap-south-1b --query 'Subnet.SubnetId' --output text)

echo "PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1"
echo "PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2"
echo "PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1"
echo "PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2"

aws ec2 create-tags --resources $PUBLIC_SUBNET_1 --tags Key=Name,Value=public-subnet-1-cli
aws ec2 create-tags --resources $PUBLIC_SUBNET_2 --tags Key=Name,Value=public-subnet-2-cli
aws ec2 create-tags --resources $PRIVATE_SUBNET_1 --tags Key=Name,Value=private-subnet-1-cli
aws ec2 create-tags --resources $PRIVATE_SUBNET_2 --tags Key=Name,Value=private-subnet-2-cli

# Only public subnets get auto-assigned public IPs
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2 --map-public-ip-on-launch

# ---------------------------------------------------------------------------
# 3. Internet Gateway
# ---------------------------------------------------------------------------
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
echo "IGW_ID=$IGW_ID"

aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=aws-ha-web-app-igw-cli
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# ---------------------------------------------------------------------------
# 4. Elastic IPs + NAT Gateways (one per AZ)
# ---------------------------------------------------------------------------
EIP_1=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
EIP_2=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
echo "EIP_1=$EIP_1"
echo "EIP_2=$EIP_2"

aws ec2 create-tags --resources $EIP_1 --tags Key=Name,Value=nat-eip-1-cli
aws ec2 create-tags --resources $EIP_2 --tags Key=Name,Value=nat-eip-2-cli

NAT_GW_1=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_1 --allocation-id $EIP_1 \
  --query 'NatGateway.NatGatewayId' --output text)
NAT_GW_2=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_2 --allocation-id $EIP_2 \
  --query 'NatGateway.NatGatewayId' --output text)
echo "NAT_GW_1=$NAT_GW_1"
echo "NAT_GW_2=$NAT_GW_2"

aws ec2 create-tags --resources $NAT_GW_1 --tags Key=Name,Value=nat-gateway-1-cli
aws ec2 create-tags --resources $NAT_GW_2 --tags Key=Name,Value=nat-gateway-2-cli

# Wait until both show "available" before continuing:
# aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_1 $NAT_GW_2 --query 'NatGateways[*].State'

# ---------------------------------------------------------------------------
# 5. Route Tables
# ---------------------------------------------------------------------------
# Public route table -> Internet Gateway
PUBLIC_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
echo "PUBLIC_RT=$PUBLIC_RT"
aws ec2 create-tags --resources $PUBLIC_RT --tags Key=Name,Value=public-rt-cli
aws ec2 create-route --route-table-id $PUBLIC_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUBLIC_RT --subnet-id $PUBLIC_SUBNET_1
aws ec2 associate-route-table --route-table-id $PUBLIC_RT --subnet-id $PUBLIC_SUBNET_2

# Private route table 1 -> NAT Gateway 1 (same AZ)
PRIVATE_RT_1=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
echo "PRIVATE_RT_1=$PRIVATE_RT_1"
aws ec2 create-tags --resources $PRIVATE_RT_1 --tags Key=Name,Value=private-rt-1-cli
aws ec2 create-route --route-table-id $PRIVATE_RT_1 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_1
aws ec2 associate-route-table --route-table-id $PRIVATE_RT_1 --subnet-id $PRIVATE_SUBNET_1

# Private route table 2 -> NAT Gateway 2 (same AZ)
PRIVATE_RT_2=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
echo "PRIVATE_RT_2=$PRIVATE_RT_2"
aws ec2 create-tags --resources $PRIVATE_RT_2 --tags Key=Name,Value=private-rt-2-cli
aws ec2 create-route --route-table-id $PRIVATE_RT_2 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_2
aws ec2 associate-route-table --route-table-id $PRIVATE_RT_2 --subnet-id $PRIVATE_SUBNET_2

# ---------------------------------------------------------------------------
# 6. Security Groups
# ---------------------------------------------------------------------------
ALB_SG=$(aws ec2 create-security-group --group-name alb-sg-cli \
  --description "Allows inbound HTTP from internet to ALB" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
echo "ALB_SG=$ALB_SG"
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

APP_SG=$(aws ec2 create-security-group --group-name app-sg-cli \
  --description "Allows inbound HTTP only from ALB" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
echo "APP_SG=$APP_SG"
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 80 --source-group $ALB_SG

BASTION_SG=$(aws ec2 create-security-group --group-name bastion-sg-cli \
  --description "Allows SSH only from admin IP" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
echo "BASTION_SG=$BASTION_SG"

# Get current public IPv4 (not IPv6) for the SSH rule
MY_IP=$(curl -s https://api.ipify.org)
echo "MY_IP=$MY_IP"
aws ec2 authorize-security-group-ingress --group-id $BASTION_SG --protocol tcp --port 22 --cidr "$MY_IP/32"

# Allow SSH from bastion into app servers
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 22 --source-group $BASTION_SG

# ---------------------------------------------------------------------------
# 7. Bastion Host
# ---------------------------------------------------------------------------
# Latest Ubuntu 26.04 (Resolute Raccoon) AMI, published by Canonical
AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)
echo "AMI_ID=$AMI_ID"

BASTION_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro \
  --key-name devops-lab-key --subnet-id $PUBLIC_SUBNET_1 \
  --security-group-ids $BASTION_SG --associate-public-ip-address \
  --query 'Instances[0].InstanceId' --output text)
echo "BASTION_ID=$BASTION_ID"

aws ec2 create-tags --resources $BASTION_ID --tags Key=Name,Value=bastion-host-cli
aws ec2 wait instance-running --instance-ids $BASTION_ID

BASTION_IP=$(aws ec2 describe-instances --instance-ids $BASTION_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "BASTION_IP=$BASTION_IP"

# ---------------------------------------------------------------------------
# 8. Launch Template (app servers)
# ---------------------------------------------------------------------------
# NOTE: launch-template-data.json must exist in this folder with AMI_ID,
# APP_SG, and base64-encoded user-data (scripts/user-data.sh) filled in.
# Generate the base64 string with:
#   USER_DATA=$(base64 -w0 scripts/user-data.sh)

LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
  --launch-template-name app-server-template-cli \
  --launch-template-data file://cli-scripts/launch-template-data.json \
  --query 'LaunchTemplate.LaunchTemplateId' --output text)
echo "LAUNCH_TEMPLATE_ID=$LAUNCH_TEMPLATE_ID"

# ---------------------------------------------------------------------------
# 9. Target Group
# ---------------------------------------------------------------------------
TARGET_GROUP_ARN=$(aws elbv2 create-target-group --name app-target-group-cli \
  --protocol HTTP --port 80 --vpc-id $VPC_ID \
  --health-check-protocol HTTP --health-check-path /health \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
  --health-check-timeout-seconds 5 --health-check-interval-seconds 30 \
  --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "TARGET_GROUP_ARN=$TARGET_GROUP_ARN"

# ---------------------------------------------------------------------------
# 10. Application Load Balancer
# ---------------------------------------------------------------------------
ALB_ARN=$(aws elbv2 create-load-balancer --name app-alb-cli \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 --security-groups $ALB_SG \
  --scheme internet-facing --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "ALB_ARN=$ALB_ARN"

aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB_DNS=$ALB_DNS"

# ---------------------------------------------------------------------------
# 11. Auto Scaling Group
# ---------------------------------------------------------------------------
aws autoscaling create-auto-scaling-group --auto-scaling-group-name app-asg-cli \
  --launch-template "LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version=\$Latest" \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --target-group-arns $TARGET_GROUP_ARN \
  --vpc-zone-identifier "$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2" \
  --health-check-type ELB --health-check-grace-period 300

aws autoscaling create-or-update-tags \
  --tags "ResourceId=app-asg-cli,ResourceType=auto-scaling-group,Key=Name,Value=app-server-cli,PropagateAtLaunch=true"

# ---------------------------------------------------------------------------
# 12. Verify
# ---------------------------------------------------------------------------
echo "Waiting a few minutes, then check:"
echo "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names app-asg-cli --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' --output table"
echo "aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table"
echo "Test in browser: http://$ALB_DNS"