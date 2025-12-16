variable "datalake_raw_athena_results_storage_bucket_name" {
  description = "name of the bucket for the for results of queries in datalake raw"
  type        = string
}

variable "datalake_raw_database_name" {
  description = "name of the athena database for datalake raw"
  type        = string
}