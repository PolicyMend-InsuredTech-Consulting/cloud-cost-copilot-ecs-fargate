# Cloud Cost Copilot on Amazon ECS (AWS Fargate)

Terraform that runs [Cloud Cost Copilot](https://policymend.tech), the read-only FinOps assistant from AWS
Marketplace, in AWS accounts **without a Kubernetes cluster**. It runs as a single Fargate task, with no
cluster to manage, no load balancer and no inbound ports. You open the UI through a Session Manager port
forward.

You need an active Cloud Cost Copilot subscription in AWS Marketplace. This repository contains only the
infrastructure code; the software is the container image you receive with the subscription.

## Download

- **Release zip:** [Releases](../../releases) (each zip has a `.sha256` checksum), also listed under
  Resources on [policymend.tech](https://policymend.tech).
- **Git:** `git clone --branch v1.0.0 https://github.com/PolicyMend-InsuredTech-Consulting/cloud-cost-copilot-ecs-fargate.git`

Check a downloaded zip: `sha256sum -c cloud-cost-copilot-ecs-fargate-1.0.0.zip.sha256`
(PowerShell: `Get-FileHash cloud-cost-copilot-ecs-fargate-1.0.0.zip` and compare).

## What it creates

| Resource | Notes |
| --- | --- |
| ECS cluster, task definition, service | One task, 0.25 vCPU / 1 GB by default |
| IAM task role | [copilot-policy.json](copilot-policy.json): read-only Cost Explorer, Bedrock invoke, AWS Marketplace license check. No write access to your resources. Plus Session Manager channels for ECS Exec. |
| IAM execution role | Pulls the image from the AWS Marketplace registry, writes logs, reads the optional API token |
| CloudWatch log group | `/ecs/cloud-cost-copilot`, 30 days. Operational events only, no questions, answers or cost figures. |
| Security group | Outbound HTTPS only; inbound 8080 only from `ingress_cidrs` (none by default) |
| VPC, public subnet, internet gateway | Only when you don't pass `subnet_ids`. No NAT gateway. |

## Prerequisites

- An active Cloud Cost Copilot subscription in AWS Marketplace, in the same account.
- AWS Cost Explorer enabled. Run Copilot in the **management (payer) account** to see every linked account's costs.
- Amazon Bedrock access to the model in `bedrock_model_id` (Anthropic models need a one-time use-case form in the Bedrock console).
- Terraform 1.5 or later, the AWS CLI v2 and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars    # set image to the URI from your subscription
terraform init
terraform plan -out copilot.tfplan
terraform apply copilot.tfplan
```

Then open the UI:

```bash
terraform output -raw connect | bash     # keeps a port forward open; browse to http://localhost:8080
```

The task becomes healthy within a minute. If the UI shows *Not licensed*, the subscription is in another account
or has expired; the reason is also in the log group.

State is kept locally. For a team, add an S3 backend in `versions.tf`.

## Options

| Variable | Default | Use |
| --- | --- | --- |
| `subnet_ids`, `vpc_id` | new VPC | Run in your own subnets. With private subnets, set `assign_public_ip = false` and provide a NAT gateway or VPC endpoints for ECR, CloudWatch Logs, SSM, Bedrock, Cost Explorer and License Manager. |
| `bedrock_model_id` | `us.anthropic.claude-opus-5-5` | Inference profile ID; `eu.`, `apac.` or `global.` outside the US |
| `api_token_ssm_parameter_arn` | none | Require `Authorization: Bearer <token>` on the API. Create it with `aws ssm put-parameter --type SecureString --name /cloud-cost-copilot/api-token --value $(openssl rand -hex 24)` |
| `enable_execute_command` | `true` | Port-forward access. ECS Exec needs a writable root filesystem, so `false` makes it read-only; then reach the task through `ingress_cidrs` (for example your VPN range) |
| `ingress_cidrs` | none | Open port 8080 (plain HTTP) to these networks. Use private ranges and an API token. |
| `cpu_architecture` | `X86_64` | `ARM64` is about 20% cheaper |
| `environment` | none | Extra `COPILOT_*` settings for the container, e.g. `{ COPILOT_COST_CACHE_TTL_SECONDS = "7200" }` |

## Costs (us-east-1, always on)

| Item | Monthly |
| --- | --- |
| Fargate, 0.25 vCPU + 1 GB, x86 ($0.04048 per vCPU-hour, $0.004445 per GB-hour) | $10.63 (ARM64: $8.51) |
| Public IPv4 address | $3.65 |
| CloudWatch Logs | cents |
| **Infrastructure total** | **about $12–14** |
| Amazon Bedrock and Cost Explorer API | pay per use: typically well under $1 for a few questions a month |

To pause it, set the service's desired count to 0 (`aws ecs update-service --cluster cloud-cost-copilot --service cloud-cost-copilot --desired-count 0`); Fargate charges stop.

## Remove

```bash
terraform destroy
```

## Support and license

Questions or problems: see the support contact on the AWS Marketplace listing. Security issues: please report
privately to the same contact rather than opening a public issue.

This Terraform code is licensed under the [Apache License 2.0](LICENSE). The Cloud Cost Copilot software is
licensed separately through your AWS Marketplace subscription.
