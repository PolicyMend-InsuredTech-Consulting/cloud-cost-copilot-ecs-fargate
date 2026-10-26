terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  # State stays local unless you add your own backend, for example:
  #   backend "s3" { bucket = "<your-state-bucket>", key = "cloud-cost-copilot.tfstate", region = "us-east-1" }
}

locals {
  default_tags = merge({ app = "cloud-cost-copilot", managed_by = "terraform" }, var.tags)
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.default_tags
  }
}
