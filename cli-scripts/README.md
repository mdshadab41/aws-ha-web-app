# CLI Implementation

This folder contains an AWS CLI-based rebuild of the same highly available architecture
documented in the main README — same VPC design, same public/private subnet layout, same
ALB + Auto Scaling Group setup — but provisioned entirely through the AWS CLI instead of
the AWS Console.

## Why this exists

The console build proves the architecture works and that it can be clicked together
correctly. This CLI build proves the same architecture can be reproduced as code —
every resource, tag, and route is explicit in `build.sh` rather than hidden behind
console screens, which is closer to how infrastructure is actually managed in most
DevOps roles.

## Files

- **`build.sh`** — the full sequence of AWS CLI commands used to provision the
  architecture, in order: VPC → subnets → Internet Gateway → NAT Gateways → route
  tables → security groups → bastion host → launch template → target group →
  Application Load Balancer → Auto Scaling Group
- **`launch-template-data.json`** — the launch template payload (AMI ID, instance
  type, security group, base64-encoded user-data) referenced by `build.sh`

## How to use

1. Make sure the AWS CLI is installed and configured (`aws configure` or
   `aws sts get-caller-identity` to confirm)
2. Update `launch-template-data.json` with your own AMI ID, security group ID, and
   base64-encoded user-data (see note below on generating the AMI ID)
3. Run the commands in `build.sh` section by section — later steps depend on
   resource IDs captured from earlier ones, so this is meant to be run
   interactively rather than as a single unattended script
4. Verify with:
   ```
   aws elbv2 describe-target-health --target-group-arn <your-target-group-arn>
   ```
   Both targets should show `healthy` before testing the app in a browser via the
   ALB's DNS name

## What was different from the console build

- **Everything needs an explicit resource ID.** The console lets you pick things
  from dropdowns by name; the CLI only understands IDs (`vpc-xxxx`, `subnet-xxxx`,
  `sg-xxxx`). Each command's output was captured into a shell variable and reused
  in later commands.
- **Finding the right AMI takes an extra step.** The CLI needs an explicit AMI ID,
  found via `aws ec2 describe-images`, filtered to Canonical's official owner ID
  (`099720109477`) and the correct Ubuntu release codename (`resolute-26.04` for
  Ubuntu 26.04 LTS).
- **Public IP lookup needs to force IPv4.** A generic "what's my IP" service can
  return an IPv6 address depending on network setup, which breaks a `/32` CIDR
  security group rule (IPv4-only notation). Using `api.ipify.org` (which returns
  IPv4 specifically) fixed this.
- **The same PEP 668 pip issue showed up again.** Ubuntu's `externally-managed-environment`
  restriction blocked `pip3 install flask` in the user-data script, exactly like
  in the console build. Fixed the same way: `pip3 install flask --break-system-packages`.
- **PowerShell variables don't persist across terminal sessions.** Losing a
  session mid-build meant re-fetching every resource ID by its `Name` tag using
  `describe-*` calls with `--filters "Name=tag:Name,Values=..."` instead of
  relying on variables that no longer existed.
- **Teardown has stricter dependency ordering than the console suggests.** Route
  tables can't be deleted while subnets are still associated with them —
  `disassociate-route-table` has to run first, even though the console handles
  this invisibly when you delete a VPC through the UI.

## Cleanup

Resources built via `build.sh` were torn down in this order: Auto Scaling Group →
Load Balancer → Target Group → bastion instance → NAT Gateways → Elastic IPs →
route table associations → route tables → Internet Gateway → launch template →
subnets → security groups → VPC. Confirmed no leftover Elastic IPs, NAT Gateways,
or running instances afterward.
