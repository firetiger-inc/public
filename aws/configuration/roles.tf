data "aws_arn" "catalog" {
  arn = format("arn:aws:glue:%s:%s:catalog",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
  )
}

data "aws_arn" "cluster" {
  arn = aws_ecs_cluster.deployment.arn
}

resource "aws_iam_role" "lambda" {
  name = format("FiretigerLambdaRole@%s", aws_s3_bucket.deployment.id)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.name
  name = format("FiretigerLambdaPolicy@%s", aws_s3_bucket.deployment.id)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },

      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },

      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          aws_s3_bucket.deployment.arn,
          format("%s/*", aws_s3_bucket.deployment.arn)
        ]
      },

      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabases",
          "glue:GetDatabase",
          "glue:GetTables",
          "glue:GetTable",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
        ]
        Resource = concat(
          [data.aws_arn.catalog.arn, aws_glue_catalog_database.iceberg.arn],
          [for _, table in aws_glue_catalog_table.iceberg : table.arn],
        )
      },

      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecretVersionIds",
        ]
        Resource = [
          aws_secretsmanager_secret.ingest_basic_auth.arn,
          aws_secretsmanager_secret.query_basic_auth.arn,
        ]
      },
    ]
  })
}

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
          "ecr:GetAuthorizationToken",

          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",

          "servicediscovery:RegisterInstance",
          "servicediscovery:DeregisterInstance",
          "servicediscovery:GetInstance",
          "servicediscovery:ListInstances",
        ]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = [
          format("arn:aws:ecr:%s:%s:repository/%s/firetiger",
            data.aws_region.current.name,
            data.aws_caller_identity.current.account_id,
          replace(aws_s3_bucket.deployment.id, ".", "-")),
          format("arn:aws:ecr:%s:%s:repository/%s/grafana",
            data.aws_region.current.name,
            data.aws_caller_identity.current.account_id,
          replace(aws_s3_bucket.deployment.id, ".", "-")),
        ]
      },

      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecretVersionIds",
        ]
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
}

resource "aws_iam_role_policy" "task" {
  role = aws_iam_role.task.name
  name = format("FiretigerTaskPolicy@%s", aws_s3_bucket.deployment.id)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          aws_s3_bucket.deployment.arn,
          format("%s/*", aws_s3_bucket.deployment.arn)
        ]
      },

      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabases",
          "glue:GetDatabase",
          "glue:GetTables",
          "glue:GetTable",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
        ]
        Resource = concat(
          [data.aws_arn.catalog.arn, aws_glue_catalog_database.iceberg.arn],
          [for _, table in aws_glue_catalog_table.iceberg : table.arn],
        )
      },

      {
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:ListDatabases",
          "athena:ListDataCatalogs",
          "athena:ListWorkGroups",
          "athena:GetDatabase",
          "athena:GetDataCatalog",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetTableMetadata",
          "athena:GetWorkGroup",
          "athena:ListTableMetadata",
          "athena:StartQueryExecution",
          "athena:StopQueryExecution"
        ]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetRandomPassword",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          aws_secretsmanager_secret.ingest_basic_auth.arn,
          aws_secretsmanager_secret.query_basic_auth.arn,
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
}

resource "aws_iam_role_policy" "deployment" {
  name = format("FiretigerDeploymentPolicy@%s", aws_s3_bucket.deployment.id)
  role = aws_iam_role.deployment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:ListTagsForResource",

          "ecs:ListClusters",
          "ecs:ListTasks",
          "ecs:ListTaskDefinitions",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",

          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",

          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",

          "athena:CreateDataCatalog",
          "athena:DeleteDataCatalog",
          "athena:GetDataCatalog",
          "athena:ListDataCatalogs",
          "athena:UpdateDataCatalog",
          "athena:TagResource",
          "athena:UntagResource",
          "athena:ListTagsForResource",

          "servicediscovery:ListNamespaces",
          "servicediscovery:ListTagsForResource",
          "servicediscovery:DeleteService",
          "servicediscovery:GetService",
          "servicediscovery:ListServices",
          "servicediscovery:ListInstances",
          "servicediscovery:UpdateService",
          "servicediscovery:TagResource",
          "servicediscovery:UntagResource",

          "lambda:CreateFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:GetProvisionedConcurrencyConfig",
          "lambda:PutProvisionedConcurrencyConfig",

          "iam:PassRole",

          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:DeleteLogStream",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource",

          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTags",

          "acm:ListCertificates",

          "route53:GetChange",
          "route53:ListHostedZones",

          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:DescribeScalingPolicies",
          "application-autoscaling:DescribeScalingActivities",
          "application-autoscaling:ListTagsForResource",
          "application-autoscaling:TagResource",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy",

          "secretsmanager:ListSecrets",
        ]
        Resource = ["*"]
      },

      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = [
          format("arn:aws:ecr:%s:%s:repository/%s/firetiger",
            data.aws_region.current.name,
            data.aws_caller_identity.current.account_id,
          replace(aws_s3_bucket.deployment.id, ".", "-")),
          format("arn:aws:ecr:%s:%s:repository/%s/grafana",
            data.aws_region.current.name,
            data.aws_caller_identity.current.account_id,
          replace(aws_s3_bucket.deployment.id, ".", "-")),
        ]
      },

      {
        Effect = "Allow"
        Action = ["ecs:*"]
        Resource = [
          data.aws_arn.cluster.arn,
          format("arn:aws:ecs:%s:%s:service/%s/*",
            data.aws_arn.cluster.region,
            data.aws_arn.cluster.account,
            aws_ecs_cluster.deployment.name,
          ),
          format("arn:aws:ecs:%s:%s:task/%s/*",
            data.aws_arn.cluster.region,
            data.aws_arn.cluster.account,
            aws_ecs_cluster.deployment.name,
          ),
          format("arn:aws:ecs:%s:%s:task-definition/%s_*:*",
            data.aws_arn.cluster.region,
            data.aws_arn.cluster.account,
            replace(aws_s3_bucket.deployment.id, ".", "_"),
          ),
        ]
      },

      {
        Effect   = "Allow"
        Action   = ["servicediscovery:GetNamespace"]
        Resource = [aws_service_discovery_http_namespace.deployment.arn]
      },

      {
        Effect   = "Allow"
        Action   = ["servicediscovery:CreateService"]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "servicediscovery:NamespaceArn" = aws_service_discovery_http_namespace.deployment.arn
          }
        }
      },

      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:GetLogGroupFields",
          "logs:GetLogRecord",
          "logs:GetQueryResults",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:DescribeQueries",
          "logs:GetLogDelivery",
          "logs:ListLogDeliveries",
          "logs:ListTagsForResource",
        ]
        Resource = [
          aws_cloudwatch_log_group.deployment.arn,
          format("%s:*", aws_cloudwatch_log_group.deployment.arn),
          format("%s:*:*", aws_cloudwatch_log_group.deployment.arn),
        ]
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
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:GetCertificate",
          "acm:ListTagsForCertificate",
        ]
        Resource = [aws_acm_certificate.deployment.arn]
      },

      {
        Effect   = "Allow"
        Action   = ["route53:*"]
        Resource = [aws_route53_zone.deployment.arn]
      },

      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:GetBucketPolicy"]
        Resource = [aws_s3_bucket.deployment.arn]
      },

      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging",
        ]
        Resource = [format("%s/firetiger/*", aws_s3_bucket.deployment.arn)]
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
    ]
  })
}
