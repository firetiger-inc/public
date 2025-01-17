resource "aws_glue_catalog_database" "iceberg" {
  name = replace(aws_s3_bucket.deployment.id, ".", "_")
}

resource "aws_glue_catalog_table" "iceberg" {
  for_each      = aws_s3_object.initial_table_metadata
  name          = each.key
  database_name = aws_glue_catalog_database.iceberg.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "format"            = "parquet"
    "table_type"        = "ICEBERG"
    "metadata_location" = format("s3://%s/%s", each.value.bucket, each.value.key)
  }

  storage_descriptor {
    location                  = jsondecode(each.value.content).location
    stored_as_sub_directories = true
  }

  lifecycle {
    ignore_changes = [
      parameters["table_type"],
      parameters["metadata_location"],
      parameters["previous_metadata_location"],
      partition_keys,
      storage_descriptor[0].sort_columns,
    ]
  }

  # We manage the initial table metadata in the S3 object below instead of
  # letting Glue manage it. This gives us more control and allows us to
  # use the same approach for other cloud platforms.
  #
  # open_table_format_input {
  #   iceberg_input {
  #     metadata_operation = "CREATE"
  #   }
  # }
}
