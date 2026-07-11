# Security Groups

| Security Group | Purpose                          | Inbound Rules                                   |
| -------------- | -------------------------------- | ----------------------------------------------- |
| alb-sg         | Attached to the ALB              | HTTP (80) from 0.0.0.0/0                        |
| app-sg         | Attached to app server instances | HTTP (80) from alb-sg; SSH (22) from bastion-sg |
| bastion-sg     | Attached to bastion host         | SSH (22) from admin IP (My IP)                  |

## Design notes

Security groups are layered so no tier is reachable except from the tier directly
above it in the traffic path:

Internet → alb-sg (port 80 only) → app-sg (port 80, ALB only)
Admin IP → bastion-sg (port 22) → app-sg (port 22, bastion only)

App servers are never directly reachable from the internet, and SSH access to app
servers is only possible by first connecting to the bastion host.
