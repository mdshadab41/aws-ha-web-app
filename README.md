# AWS Highly Available Web Application

## Overview
This project implements a production-style, highly available web application architecture on AWS, built entirely through the AWS Console (no Terraform/IaC) to demonstrate hands-on understanding of core AWS networking and compute services.

The architecture spans two Availability Zones for fault tolerance. Public subnets host NAT gateways and a bastion host for secure SSH access, while private subnets host the actual application servers — never exposed directly to the internet. An Application Load Balancer distributes incoming traffic across both zones, and an Auto Scaling Group ensures the application can scale horizontally based on load, with unhealthy instances automatically replaced.

A simple Flask application is deployed as the workload, allowing the load balancing behavior to be verified directly — each request shows which instance served it.

## Why this project
Most tutorials stop at "launch an EC2 instance." This project instead focuses on how production traffic is actually routed, secured, and scaled — the same patterns used in real AWS environments — while keeping the app itself intentionally simple so the infrastructure is the focus.

## Architecture
![Architecture Diagram](architecture-diagram.png)

- **VPC** across 2 Availability Zones
- **Public subnets**: NAT Gateway (outbound internet for private instances), Bastion host (SSH access)
- **Private subnets**: Application servers running Flask, managed by an Auto Scaling Group
- **Application Load Balancer**: internet-facing, routes to healthy targets only
- **Security Groups**: least-privilege access between ALB, app servers, and bastion

## Tech stack
AWS VPC, EC2, Auto Scaling Groups, Application Load Balancer, NAT Gateway, Security Groups, Python (Flask)

## What I'd add for a full production setup
HTTPS via ACM, WAF, RDS (Multi-AZ) for persistent data, CloudWatch alarms + CloudTrail, CI/CD pipeline, Route 53 custom domain.