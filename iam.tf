# --------------------------------------------------------------------------------------- Task role
# What Copilot itself can do: read-only Cost Explorer, Bedrock invoke and the AWS Marketplace license check.
# copilot-policy.json is the same policy the Helm (Amazon EKS) instructions attach to the pod role.
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

#trivy:ignore:AVD-AWS-0057 Cost Explorer and License Manager actions have no resource-level permissions
resource "aws_iam_role_policy" "copilot" {
  name   = "copilot"
  role   = aws_iam_role.task.id
  policy = file("${path.module}/copilot-policy.json")
}

# Session Manager channels for ECS Exec (port forwarding to the UI). They have no resource-level scoping.
#trivy:ignore:AVD-AWS-0057
resource "aws_iam_role_policy" "exec" {
  count = var.enable_execute_command ? 1 : 0
  name  = "ecs-exec"
  role  = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })
}

# ---------------------------------------------------------------------------------- Execution role
# What ECS needs to start the task: pull the image from the AWS Marketplace registry, write logs, read the token.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "api_token" {
  count = var.api_token_ssm_parameter_arn != "" ? 1 : 0
  name  = "read-api-token"
  role  = aws_iam_role.execution.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "ssm:GetParameters", Resource = var.api_token_ssm_parameter_arn }]
  })
}
