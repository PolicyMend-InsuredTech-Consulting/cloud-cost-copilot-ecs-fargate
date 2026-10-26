output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "log_group" {
  value = aws_cloudwatch_log_group.this.name
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "connect" {
  description = "Open the UI at http://localhost:8080 through a Session Manager port forward (needs the session-manager-plugin)"
  value       = !var.enable_execute_command ? "ECS Exec is off: reach the task's private IP on port 8080 from ingress_cidrs." : <<-EOT
    TASK=$(aws ecs list-tasks --region ${var.region} --cluster ${aws_ecs_cluster.this.name} --service-name ${aws_ecs_service.this.name} --query 'taskArns[0]' --output text | awk -F/ '{print $NF}')
    RUNTIME=$(aws ecs describe-tasks --region ${var.region} --cluster ${aws_ecs_cluster.this.name} --tasks $TASK --query 'tasks[0].containers[0].runtimeId' --output text)
    aws ssm start-session --region ${var.region} --target ecs:${aws_ecs_cluster.this.name}_$${TASK}_$${RUNTIME} \
      --document-name AWS-StartPortForwardingSessionToRemoteHost \
      --parameters '{"host":["localhost"],"portNumber":["8080"],"localPortNumber":["8080"]}'
  EOT
}
