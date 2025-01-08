# Secrets used by Firetiger services to authenticate incoming requests.
#
# The secrets containers here must be configured as part of the initial setup
# because AWS appends random characters to the ARN, which means that we cannot
# predict the ARN ahead of time.

resource "aws_secretsmanager_secret" "ingest_basic_auth" {
  name                    = format("firetiger/ingest/basic-auth@%s", aws_s3_bucket.deployment.id)
  description             = "Secret storing the Firetiger ingest basic auth credentials"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
    FiretigerSecretName = "firetiger/ingest/basic-auth"
  }
}

resource "aws_secretsmanager_secret" "query_basic_auth" {
  name                    = format("firetiger/query/basic-auth@%s", aws_s3_bucket.deployment.id)
  description             = "Secret storing the Firetiger query basic auth credentials"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = {
    FiretigerDeployment = aws_s3_bucket.deployment.id
    FiretigerSecretName = "firetiger/query/basic-auth"
  }
}

# We generate the secret values here so they do not need to appear anywhere in
# the terraform state managing the deployment of Firetiger resources.
#
# The authentication tokens are configured to not include special characters
# because these make copy/pasting the values error-prone.

data "aws_secretsmanager_random_password" "ingest_basic_auth" {
  password_length     = 32
  exclude_punctuation = true
}

data "aws_secretsmanager_random_password" "query_basic_auth" {
  password_length     = 32
  exclude_punctuation = true
}

resource "aws_secretsmanager_secret_version" "ingest_basic_auth" {
  secret_id     = aws_secretsmanager_secret.ingest_basic_auth.id
  secret_string = data.aws_secretsmanager_random_password.ingest_basic_auth.random_password
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "query_basic_auth" {
  secret_id     = aws_secretsmanager_secret.query_basic_auth.id
  secret_string = data.aws_secretsmanager_random_password.query_basic_auth.random_password
  lifecycle {
    ignore_changes = [secret_string]
  }
}
