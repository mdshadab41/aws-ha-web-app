# Target Group Health Check Configuration

**Target Group:** app-target-group
**Target type:** Instances
**Protocol / Port:** HTTP / 80
**VPC:** aws-ha-web-app-vpc

## Health check settings

| Setting             | Value      |
| ------------------- | ---------- |
| Protocol            | HTTP       |
| Path                | /health    |
| Healthy threshold   | 2          |
| Unhealthy threshold | 2          |
| Timeout             | 5 seconds  |
| Interval            | 30 seconds |
| Success codes       | 200        |

## Why a dedicated /health endpoint

The Flask app exposes a separate `/health` route (returning a plain 200 OK) rather
than relying on the `/` route for health checks. This keeps health check logic simple
and decoupled from the actual application response, which is standard practice in
production load-balanced systems.

## Troubleshooting note

During setup, both initial instances failed health checks with 0/2 healthy targets.
Root cause: Ubuntu's PEP 668 "externally-managed-environment" restriction blocked
`pip3 install flask` in the EC2 bootstrap script, so Flask never installed and the
app never started. Fixed by adding `--break-system-packages` to the pip install
command in scripts/user-data.sh.
