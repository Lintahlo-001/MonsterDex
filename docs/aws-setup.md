# AWS Setup

[← Back to README](../README.md)

> The original AWS resources described here have been **terminated**. Use this guide to recreate them in your own account.

Suggested order: VPCs → peering → EC2 → RDS → security groups → [Tailscale](tailscale.md) → [API server](api.md) → Lambda.

## Contents

- [VPC Setup](#vpc-setup)
- [VPC Peering](#vpc-peering)
- [EC2 Instance](#ec2-instance)
- [RDS Database](#rds-database)
- [Security Groups](#security-groups)
- [Lambda Function](#lambda-function)
- [Security Considerations](#security-considerations)

## VPC Setup

| VPC | Region | CIDR | Purpose |
|-----|--------|------|---------|
| `MyParisVPC` | eu-west-3 (Paris) | `10.0.0.0/16` | Web Server |
| `MyNVirginiaVPC` | us-east-1 (N. Virginia) | `10.1.0.0/16` | RDS Database |

Each VPC has:

- A public subnet (`10.x.1.0/24`)
- An Internet Gateway
- A Route Table with `0.0.0.0/0 → IGW`

## VPC Peering

A cross-region VPC peering connection links Paris (Web) → N. Virginia (RDS).

**Route Table updates required:**

| Route Table | Destination | Target |
|-------------|-------------|--------|
| Paris (Web) | `10.1.0.0/16` | Peering Connection |
| N. Virginia (DB) | `10.0.0.0/16` | Peering Connection |

## EC2 Instance

| Instance | Region | Purpose | AMI |
|----------|--------|---------|-----|
| `MyParisWebServer` | eu-west-3 (Paris) | Node.js API + Tailscale | Amazon Linux 2023 |

> The database is fully managed by **Amazon RDS**, so no database EC2 instance is required.

## RDS Database

| Setting | Value |
|---------|-------|
| Engine | MySQL 8.0 |
| Region | us-east-1 (N. Virginia) |
| DB Name | `haumonstersDB` |
| Instance | `db.t3.micro` (Free Tier) |
| VPC | `MyNVirginiaVPC` |
| Publicly Accessible | No |

The schema is described in [database.md](database.md).

## Security Groups

**Web Server (`MyParisSG`), Paris:**

| Type | Protocol | Port | Source |
|------|----------|------|--------|
| Custom TCP | TCP | 8000 | `100.64.0.0/10` (Tailscale range) |
| HTTP | TCP | 80 | `100.64.0.0/10` (Tailscale range) |
| HTTPS | TCP | 443 | `100.64.0.0/10` (Tailscale range) |
| SSH | TCP | 22 | Your IP |

> Port 8000 is only accessible through Tailscale VPN. Direct internet access is blocked.

**RDS (`rds-ec2-2`), N. Virginia:**

| Type | Protocol | Port | Source |
|------|----------|------|--------|
| MySQL/Aurora | TCP | 3306 | `10.0.0.0/16` (Paris VPC CIDR) |

## Lambda Function

| Setting | Value |
|---------|-------|
| Name | `haumonsters-ec2-toggle` |
| Runtime | Python 3.12 |
| Region | us-east-1 |
| Role | Requires `AmazonEC2FullAccess` (see [Security Considerations](#security-considerations) for a tighter option) |
| Function URL | Enabled, auth type `NONE`, so the app can call it without AWS credentials |

It is used to start, stop and check the web server EC2 instance from the mobile app.

The code is in [`lambda/ec2_toggle.py`](../lambda/ec2_toggle.py). Paste it into the function, deploy, then copy the Function URL into `LAMBDA_URL` in your `env.json` (see [flutter-app.md](flutter-app.md#configuration)).

**Request body** (`POST`, JSON):

| Field | Required | Values |
|-------|----------|--------|
| `action` | yes | `status`, `start`, `stop` |
| `instance_id` | yes | EC2 instance ID, e.g. `i-0123456789abcdef0` |
| `region` | no | Defaults to `eu-west-3` |

## Security Considerations

With the current setup, **anyone who knows the Function URL can start or stop EC2 instances in your account**, because the URL has no authentication, the function takes `instance_id` and `region` from the request, and the role has `AmazonEC2FullAccess`.

Recommended fixes, roughly in order of effort:

1. **Do not publish the URL.** If it has ever been committed to a public repository, delete the Function URL and create a new one. Keep the new value out of Git by putting it only in your git-ignored `env.json` (see [flutter-app.md](flutter-app.md#configuration)).
2. **Scope the IAM role** to only `ec2:DescribeInstances`, `ec2:StartInstances` and `ec2:StopInstances`, restricted to the ARN of your web server instance, instead of `AmazonEC2FullAccess`.
3. **Ignore the request's `instance_id` and `region`.** Read them from Lambda environment variables so a caller can only ever act on your one server.
4. **Add authentication** (an `AWS_IAM` Function URL, or an API Gateway in front) instead of auth type `NONE`.
