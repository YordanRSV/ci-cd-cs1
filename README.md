# Semester3 DevOps & IaC

## Prerequisites
- AWS account credentials (use GitHub Actions secrets)
- S3 bucket and DynamoDB table for Terraform remote state (optional but recommended)
- GitHub repository connected to this workspace

## 1) DevOps Platform Setup
- Create a new GitHub repo and push this project.
- In repo Settings → Secrets and variables → Actions, add:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `TF_VAR_DB_PASSWORD`

## 2) Terraform Remote State (recommended)
Update `terraform/backend.tf` with your S3 bucket and DynamoDB table. If you do not have them yet, you can comment out or remove `backend.tf` temporarily to use local state.

## 3) Local Terraform Workflow (optional)
```bash
cd terraform
terraform init
terraform validate
terraform plan -var db_password=YOUR_PASSWORD
terraform apply -auto-approve -var db_password=YOUR_PASSWORD
```

## 4) CI/CD
- Workflow `.github/workflows/terraform-ecs.yml` runs plan on PR and applies on `main`.
- It builds and pushes Docker image to ECR and forces a new ECS service deployment.

## 5) What Gets Deployed
- VPC with public and private subnets, IGW, NAT
- ALB + target group + listener
- ECS Fargate service behind ALB
- ECR repository
- RDS PostgreSQL (private, encrypted)

Outputs to note after apply:
- `alb_dns_name` → test in browser
- `rds_endpoint` → use for application connection from ECS tasks

## 6) Hub-Spoke Network Design (Phase 2)
This repo currently contains a single VPC (spoke). To implement hub-spoke:
- Create a new module or folder `network/` with:
  - Hub VPC with shared services (e.g., DNS forwarders, firewalls)
  - Spoke VPCs per workload (web, data)
  - VPC peering or AWS Transit Gateway to connect hub↔spokes
  - Centralized egress via NAT in hub, and spoke routes to TGW/peering
- Replace direct IGW/NAT in spokes if centralizing egress.

## 7) Private DNS for PaaS (RDS and others)
- Add `aws_vpc_endpoint` resources (e.g., for Secrets Manager, SSM) with `private_dns_enabled = true` in private subnets.
- RDS is private; ECS tasks in private subnets connect over VPC DNS.
- Use Route 53 private hosted zones for internal custom names if needed.

## 8) Front-end Auto-scaling
- See `terraform/autoscaling.tf`. Tune `min/max_capacity`, `target_value`, and thresholds per SLA.

## 9) Operating
- Push to `main` to trigger apply and deployment.
- View ALB DNS from Terraform outputs.
- For rollbacks, revert commit and push; or rebuild a previous image tag.

## 10) Next Steps
- Split stacks by modules (vpc, alb, ecs, rds) and workspaces per env.
- Add WAF on ALB, HTTPS listener with ACM certificate.
- Add secrets retrieval via AWS Secrets Manager for DB creds, inject into task definition.
- Replace hard-coded AZs/subnets with variables. 