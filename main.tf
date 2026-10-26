# Container Insights adds per-metric charges; the app's health is visible in the service events and logs.
#trivy:ignore:AVD-AWS-0034
resource "aws_ecs_cluster" "this" {
  name = var.name
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# Logs hold operational events only (no questions, answers or cost figures).
#trivy:ignore:AVD-AWS-0017 the AWS-managed key is enough for operational logs; a customer-managed key adds $1/month
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
}

locals {
  environment = concat(
    [
      { name = "AWS_REGION", value = var.region },
      { name = "COPILOT_LLM_PROVIDER", value = "bedrock" },
      { name = "COPILOT_BEDROCK_MODEL_ID", value = var.bedrock_model_id },
      { name = "COPILOT_LOG_LEVEL", value = var.log_level },
    ],
    var.bedrock_region != "" ? [{ name = "COPILOT_BEDROCK_REGION", value = var.bedrock_region }] : [],
  )
  secrets = var.api_token_ssm_parameter_arn != "" ? [{ name = "COPILOT_API_TOKEN", valueFrom = var.api_token_ssm_parameter_arn }] : []
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([{
    name         = "copilot"
    image        = var.image
    essential    = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment  = local.environment
    secrets      = local.secrets
    # ECS Exec's agent must write to the root filesystem; without it the filesystem stays read-only.
    readonlyRootFilesystem = !var.enable_execute_command
    linuxParameters        = { initProcessEnabled = var.enable_execute_command }
    mountPoints            = [{ sourceVolume = "tmp", containerPath = "/tmp" }]
    healthCheck = {
      command     = ["CMD", "python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz').status==200 else 1)"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "copilot"
      }
    }
  }])
}

# One task: conversation memory is held in-process.
resource "aws_ecs_service" "this" {
  name                   = var.name
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = var.assign_public_ip
  }

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) == 0 || var.vpc_id != ""
      error_message = "Set vpc_id when you pass subnet_ids."
    }
    precondition {
      condition     = length(var.subnet_ids) > 0 || var.assign_public_ip
      error_message = "The VPC this module creates has no NAT gateway: keep assign_public_ip = true, or pass your own subnets."
    }
  }
}
