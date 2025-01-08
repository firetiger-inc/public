resource "aws_iam_role" "execution" {
  name        = format("FiretigerExecutionRole@%s", aws_s3_bucket.deployment.id)
  description = "IAM role assumed by ECS Fargate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
    FiretigerRoleName   = "FiretigerExecutionRole"
  }
}

resource "aws_iam_role_policy" "execution" {
  role = aws_iam_role.execution.name
  name = format("FiretigerExecutionPolicy@%s", aws_s3_bucket.deployment.id)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.ingest_basic_auth.arn,
          aws_secretsmanager_secret.query_basic_auth.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role" "task" {
  name        = format("FiretigerTaskRole@%s", aws_s3_bucket.deployment.id)
  description = "IAM role assumed by ECS tasks of Firetiger deployments"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
    FiretigerRoleName   = "FiretigerTaskRole"
  }
}

resource "aws_iam_role_policy" "task" {
  role = aws_iam_role.task.name
  name = format("FiretigerTaskPolicy@%s", aws_s3_bucket.deployment.id)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.deployment.arn]
      },

      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [format("%s/*", aws_s3_bucket.deployment.arn)]
      },

      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabases",
          "glue:GetDatabase",
          "glue:GetTables",
          "glue:GetTable",
          "glue:UpdateTable",
        ]
        Resource = [
          data.aws_arn.catalog.arn,
          data.aws_arn.database.arn,
          data.aws_arn.logs.arn,
          data.aws_arn.metrics.arn,
          data.aws_arn.traces.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role" "deployment" {
  name        = format("FiretigerDeploymentRole@%s", aws_s3_bucket.deployment.id)
  description = "IAM role assumed to deploy Firetiger to customer accounts"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::975050257559:root"
        }
      }
    ]
  })

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
    FiretigerRoleName   = "FiretigerDeploymentRole"
  }
}

resource "aws_iam_role_policy" "deployment" {
  name = format("FiretigerDeploymentPolicy@%s", aws_s3_bucket.deployment.id)
  role = aws_iam_role.deployment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:CreateCluster"]
        Resource = ["arn:aws:ecs:*:*:cluster/*"]
        Condition = {
          StringEquals = {
            "aws:RequestTag/Name" = local.cluster
          }
        }
      },

      {
        Action = [
          "ecs:ListTaskDefinitions",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = ["ecs:*"]
        Resource = [
          format("arn:aws:ecs:*:*:cluster/%s", local.cluster),
          format("arn:aws:ecs:*:*:service/%s/*", local.cluster),
          format("arn:aws:ecs:*:*:task/%s/*", local.cluster),
          "arn:aws:ecs:*:*:task-definition/*:*",
        ]
      },

      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          format("arn:aws:logs:*:*:log-group:/ecs/%s", aws_s3_bucket.deployment.id),
          format("arn:aws:logs:*:*:log-group:/ecs/%s:*", aws_s3_bucket.deployment.id),
        ]
      },

      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTags",
        ]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:*"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/ft-*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/ft-*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/ft-*/*/*",
          "arn:aws:elasticloadbalancing:*:*:targetgroup/ft-*/*",
        ]
      },

      {
        Effect   = "Allow"
        Action   = ["acm:DescribeCertificate", "acm:ListCertificates"]
        Resource = ["*"]
      },

      {
        Effect   = "Allow"
        Action   = ["acm:*"]
        Resource = [aws_acm_certificate.deployment.arn]
      },

      {
        Effect   = "Allow"
        Action   = ["route53:GetChange", "route53:ListHostedZones"]
        Resource = ["*"]
      },

      {
        Effect   = "Allow"
        Action   = ["route53:*"]
        Resource = [aws_route53_zone.deployment.arn]
      },

      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [aws_s3_bucket.deployment.arn]
      },

      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [format("%s/*", aws_s3_bucket.deployment.arn)]
      },

      {
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:CreateTable",
          "glue:DeleteDatabase",
          "glue:DeleteTable",
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetTags",
          "glue:TagResource",
          "glue:UpdateTable",
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          format("arn:aws:glue:*:*:database/%s", local.database),
          format("arn:aws:glue:*:*:table/%s/*", local.database),
          format("arn:aws:glue:*:*:userDefinedFunction/%s/*", local.database),
        ]
      },

      {
        Effect = "Allow"
        Action = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:DescribeScalingPolicies",
          "application-autoscaling:ListTagsForResource",
          "application-autoscaling:TagResource",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy",
        ]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:PassRole",
        ]
        Resource = [
          aws_iam_role.execution.arn,
          aws_iam_role.task.arn,
          "arn:aws:iam::*:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService",
        ]
      },

      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = ["arn:aws:iam::*:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"]
      },

      {
        Effect   = "Allow"
        Action   = ["secretsmanager:ListSecrets"]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
        ]
        Resource = ["*"]
      }
    ]
  })
}
