# Example Terraform configuration for deploying Firetiger ECS Events integration
# using the GitHub-hosted module

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Deploy the Firetiger ECS Events integration module
module "firetiger_ecs_events" {
  source = "github.com/firetiger-inc/public//ingest/aws/ecs/events/terraform?ref=main"

  # Naming and identification
  name_prefix = "firetiger-for-firetiger"

  # Firetiger endpoint configuration
  firetiger_endpoint = "https://ingest.firetiger-for-firetiger.firetigerapi.com"
  firetiger_username = "firetiger-for-firetiger"
  firetiger_password = "your-password-here" # Replace with your actual password

  # EventBridge configuration
  event_bridge_rule_name = "firetiger-ecs-task-stopped-events"

  # Event pattern to capture ECS task state changes
  # This captures all STOPPED tasks in the firetiger-for-firetiger cluster
  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      lastStatus = ["STOPPED"]
      clusterArn = [
        {
          suffix = ":cluster/firetiger-for-firetiger"
        }
      ]
    }
  })

  # API destination rate limiting
  invocation_rate_per_second = 20

  # Optional: Enable dead letter queue for failed events
  enable_dead_letter_queue            = true
  dead_letter_queue_retention_seconds = 86400 # 1 day

  # Optional: Use default event bus (can be changed to custom event bus)
  event_bridge_bus = "default"
}

