
resource "aws_athena_database" "datalake_raw" {
  name   = var.datalake_raw_database_name
  bucket = var.datalake_raw_athena_results_storage_bucket_name

  encryption_configuration {
    encryption_option = "SSE_S3"
  }
  force_destroy = true
}

resource "aws_athena_workgroup" "athena_workgroup" {
  name = "${var.datalake_raw_database_name}_workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${var.datalake_raw_athena_results_storage_bucket_name}/output/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
    engine_version {
      selected_engine_version = "Athena engine version 2"
    }

  }
  force_destroy = true
}
