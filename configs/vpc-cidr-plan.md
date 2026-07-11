# VPC CIDR Plan

**Region:** ap-south-1 (Mumbai)
**VPC:** aws-ha-web-app-vpc — 10.0.0.0/16

| Subnet           | AZ          | CIDR        | Type    |
| ---------------- | ----------- | ----------- | ------- |
| public-subnet-1  | ap-south-1a | 10.0.1.0/24 | Public  |
| public-subnet-2  | ap-south-1b | 10.0.2.0/24 | Public  |
| private-subnet-1 | ap-south-1a | 10.0.3.0/24 | Private |
| private-subnet-2 | ap-south-1b | 10.0.4.0/24 | Private |

## Route Tables

| Route Table  | Associated Subnet                | Destination | Target           |
| ------------ | -------------------------------- | ----------- | ---------------- |
| public-rt    | public-subnet-1, public-subnet-2 | 0.0.0.0/0   | Internet Gateway |
| private-rt-1 | private-subnet-1                 | 0.0.0.0/0   | nat-gateway-1    |
| private-rt-2 | private-subnet-2                 | 0.0.0.0/0   | nat-gateway-2    |

## Design notes

Public and private subnets are paired by Availability Zone so each zone's NAT gateway
only serves that zone's private subnet. This keeps the two AZs fully independent —
if one AZ's NAT gateway fails, only that AZ's private subnet loses outbound internet
access, not both.
