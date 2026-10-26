variable "region" {
  description = "Region to run Copilot in. Bedrock is called in this region unless bedrock_region is set."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the ECS cluster, service, roles and log group"
  type        = string
  default     = "cloud-cost-copilot"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be 2-31 lower-case letters, digits or hyphens, starting with a letter."
  }
}

variable "tags" {
  description = "Extra tags for every resource"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------- Container
variable "image" {
  description = "Image URI from your AWS Marketplace subscription, e.g. 709825985650.dkr.ecr.us-east-1.amazonaws.com/<seller>/cloud-cost-copilot:1.0.0"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+:.+$", var.image))
    error_message = "image must be a full ECR image URI with a tag."
  }
}

variable "cpu" {
  description = "Task vCPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB. 1024 fits one user at a time; use 2048 for a team."
  type        = number
  default     = 1024
}

variable "cpu_architecture" {
  description = "X86_64, or ARM64 (about 20% cheaper) when the image version supports it"
  type        = string
  default     = "X86_64"
  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

# --------------------------------------------------------------------------------------- Copilot
variable "bedrock_model_id" {
  description = "Bedrock inference profile ID: us. prefix in US regions; eu., apac. or global. elsewhere"
  type        = string
  default     = "us.anthropic.claude-opus-5-5"
}

variable "bedrock_region" {
  description = "Region for Bedrock calls. Empty: var.region."
  type        = string
  default     = ""
}

variable "api_token_ssm_parameter_arn" {
  description = "ARN of an SSM SecureString parameter holding the API bearer token (encrypted with the AWS-managed aws/ssm key). Empty: no token."
  type        = string
  default     = ""
}

variable "log_level" {
  type    = string
  default = "INFO"
}

variable "log_retention_days" {
  type    = number
  default = 30
}

# --------------------------------------------------------------------------------------- Network
variable "subnet_ids" {
  description = "Existing subnets for the task. Empty: create a small VPC with one public subnet (no NAT gateway)."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC of subnet_ids. Required when subnet_ids is set."
  type        = string
  default     = ""
}

variable "assign_public_ip" {
  description = "Give the task a public IPv4 address for outbound calls to AWS APIs ($3.65/month). Set false for private subnets with a NAT gateway or VPC endpoints."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR of the VPC created when subnet_ids is empty"
  type        = string
  default     = "10.80.0.0/24"
}

# ---------------------------------------------------------------------------------------- Access
variable "enable_execute_command" {
  description = <<-EOT
    Reach the UI through a Session Manager port forward (no inbound ports). ECS Exec needs a writable root
    filesystem, so true turns readonlyRootFilesystem off. false keeps the filesystem read-only; reach the task
    through ingress_cidrs instead.
  EOT
  type        = bool
  default     = true
}

variable "ingress_cidrs" {
  description = "CIDRs (for example your VPN or VPC range) allowed to reach port 8080 directly. Plain HTTP: set an API token and use private networks only."
  type        = list(string)
  default     = []
}
