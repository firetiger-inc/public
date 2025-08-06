output "event_bridge_rule_name" {
  description = "Name of the EventBridge rule capturing ECS task state change events"
  value       = aws_cloudwatch_event_rule.ecs_task_state_change_rule.name
}

output "event_bridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.ecs_task_state_change_rule.arn
}

output "api_destination_endpoint" {
  description = "Firetiger API destination endpoint"
  value       = "${var.firetiger_endpoint}/aws/eventbridge/ecs-task-state-change"
}

output "api_destination_arn" {
  description = "ARN of the Firetiger API destination"
  value       = aws_cloudwatch_event_api_destination.firetiger_api_destination.arn
}

output "connection_arn" {
  description = "ARN of the EventBridge connection"
  value       = aws_cloudwatch_event_connection.firetiger_connection.arn
}

output "dead_letter_queue_url" {
  description = "URL of the dead letter queue for failed events"
  value       = var.enable_dead_letter_queue ? aws_sqs_queue.event_dead_letter_queue[0].id : null
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue"
  value       = var.enable_dead_letter_queue ? aws_sqs_queue.event_dead_letter_queue[0].arn : null
}

output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL to monitor EventBridge rule metrics"
  value       = "https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${var.name_prefix}-ECS-OOM-Events"
}

output "setup_complete_message" {
  description = "Setup completion message with next steps"
  value = <<-EOT
    🎉 Firetiger EventBridge ECS Integration deployed successfully!

    EventBridge Rule: ${aws_cloudwatch_event_rule.ecs_task_state_change_rule.name}
    API Destination: ${var.firetiger_endpoint}/aws/eventbridge/ecs-task-state-change
    Rate Limit: ${var.invocation_rate_per_second} events/second
    Dead Letter Queue: ${var.enable_dead_letter_queue}

    Next steps:
    1. Verify ECS task state change events are appearing in Firetiger at: ${var.firetiger_endpoint}
    2. Monitor EventBridge rule metrics in CloudWatch
    3. Check dead letter queue for any failed deliveries (if enabled)
    4. Adjust rate limits if needed based on your ECS task volume
    5. Modify the EventPattern parameter to capture different task state changes as needed

    🔗 EventBridge Rules Console: https://${data.aws_region.current.id}.console.aws.amazon.com/events/home?region=${data.aws_region.current.id}#/rules
    📊 CloudWatch Logs: https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#logsV2:log-groups/log-group/$252Faws$252Fevents$252Frule$252F${var.event_bridge_rule_name}

    For troubleshooting, see the deployment README.md file.
  EOT
}