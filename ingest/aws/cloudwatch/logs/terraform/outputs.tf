output "lambda_function_name" {
  description = "Name of the CloudWatch logs ingestion Lambda function"
  value       = aws_lambda_function.cloudwatch_logs_ingester.function_name
}

output "lambda_function_arn" {
  description = "ARN of the CloudWatch logs ingestion Lambda function"
  value       = aws_lambda_function.cloudwatch_logs_ingester.arn
}

output "lambda_log_group_name" {
  description = "CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

output "monitored_log_groups" {
  description = "Number of CloudWatch log groups being monitored"
  value       = aws_cloudformation_stack.subscription_filter_manager.outputs["MonitoredLogGroups"]
}

output "filter_count" {
  description = "Number of subscription filters created"
  value       = aws_cloudformation_stack.subscription_filter_manager.outputs["FilterCount"]
}

output "setup_complete_message" {
  description = "Setup completion message with next steps"
  value = <<-EOT
    🎉 Firetiger CloudWatch Logs integration deployed successfully!

    Lambda Function: ${aws_lambda_function.cloudwatch_logs_ingester.function_name}
    Monitored Log Groups: ${aws_cloudformation_stack.subscription_filter_manager.outputs["MonitoredLogGroups"]}

    Next steps:
    1. Verify logs are appearing in Firetiger at: ${var.firetiger_endpoint}
    2. Monitor Lambda function logs in CloudWatch: ${aws_cloudwatch_log_group.lambda_log_group.name}
    3. Adjust log group patterns if needed and update the stack

    🔗 Lambda Function Console: https://${data.aws_region.current.name}.console.aws.amazon.com/lambda/home?region=${data.aws_region.current.name}#/functions/${aws_lambda_function.cloudwatch_logs_ingester.function_name}
  EOT
}