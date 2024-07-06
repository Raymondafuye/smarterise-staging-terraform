module "aws_athena" {
  source                                          = "./aws-athena"
  datalake_raw_athena_results_storage_bucket_name = var.datalake_raw_athena_results_storage_bucket_name
  datalake_raw_database_name                      = var.datalake_raw_database_name
}

module "aws_iot" {
  source                             = "./aws-iot"
  iot_device_certificate_bucket_name = module.s3.iot_device_certificate_bucket_name
  device_data_stream_name            = module.aws_kinesis_data_stream.device_data_stream_name
  device_data_stream_arn             = module.aws_kinesis_data_stream.device_data_stream_arn
  kinesis_kms_key_arn                = module.aws_kinesis_data_stream.kinesis_kms_key_arn
  smart_device_names                 = var.smart_device_names
}

module "aws_kinesis_data_stream" {
  source      = "./aws-kinesis-data-stream"
  account_id  = module.meta.account_id
  region_name = module.meta.aws_active_region_name
}

module "s3" {
  source                                          = "./aws-s3"
  datalake_raw_athena_results_storage_bucket_name = var.datalake_raw_athena_results_storage_bucket_name
  iot_device_certificate_bucket_name              = var.iot_device_certificate_bucket_name
  rds_state_bucket_name                           = var.rds_state_bucket_name
}

module "aws-lambda" {
  source                                          = "./aws-lambda"
  device_kinesis_data_stream_arn                  = module.aws_kinesis_data_stream.device_data_stream_arn
  datalake_raw_bucket_arn                         = module.s3.datalake_raw_bucket_arn
  datalake_raw_athena_results_bucket_arn          = module.s3.datalake_raw_athena_results_bucket_arn
  parsed_device_kinesis_data_stream_arn           = module.aws_kinesis_data_stream.parsed_device_data_stream_arn
  smart_deivce_to_rds_env_vars                    = { "CLUSTER_ARN" : module.rds.rds_cluster_arn, "SECRET_ARN" : module.rds.rds_cluster_secret_arn }
  rds_cluster_arn                                 = module.rds.rds_cluster_arn
  rds_cluster_secret_arn                          = module.rds.rds_cluster_secret_arn
  smart_device_to_s3_raw_lambda_function_env_vars = { "S3_RAW_BUCKET_NAME" : module.s3.datalake_raw_bucket_name, "DATABASE_RAW" : module.aws_athena.athena_raw_database, "PARSED_DEVICE_KINESIS_DATA_STREAM_NAME" : module.aws_kinesis_data_stream.parsed_device_data_stream_name }
  connect_to_aurora_lambda_function_env_vars      = { "CLUSTER_ARN" : module.rds.rds_cluster_arn, "SECRET_ARN" : module.rds.rds_cluster_secret_arn }
}

module "rds" {
  source              = "./aws-rds"
  private_subnets     = module.aws-vpc.private_subnets
  vpc_cidr_block      = module.aws-vpc.vpc_cidr_block
  vpc_ipv6_cidr_block = module.aws-vpc.vpc_ipv6_cidr_block
  vpc_id              = module.aws-vpc.vpc_id
}

module "web-app" {
  source                 = "./web-app"
  smarterise_domain_root = var.smarterise_domain_root
  smarterise_dns_zone_id = module.aws-route53.smarterise_demo_dns_zone_id
}

module "aws-route53" {
  source                 = "./aws-route53"
  smarterise_domain_root = var.smarterise_domain_root
}

module "aws-ecr" {
  source = "./aws-ecr"
}

module "aws-ecs" {
  source                           = "./aws-ecs"
  environment                      = var.environment
  aws_account_id                   = module.meta.account_id
  region                           = module.meta.aws_active_region_name
  api_image_repository_name        = module.aws-ecr.smarterise_api_ecr_repository_name
  private_subnets                  = module.aws-vpc.private_subnets
  public_subnets                   = module.aws-vpc.public_subnets
  vpc_id                           = module.aws-vpc.vpc_id
  smarterise_domain_root           = var.smarterise_domain_root
  smarterise_dns_zone_id           = module.aws-route53.smarterise_demo_dns_zone_id
  rds_cluster_arn                  = module.rds.rds_cluster_arn
  rds_cluster_secret_arn           = module.rds.rds_cluster_secret_arn
  rds_connection_string_secret_arn = module.rds.rds_connection_string_secret_arn

}

module "aws-vpc" {
  source = "./aws-vpc"
}

module "aws-sagemaker" {
  source                                 = "./aws-sagemaker"
  datalake_raw_bucket_arn                = module.s3.datalake_raw_bucket_arn
  datalake_raw_athena_results_bucket_arn = module.s3.datalake_raw_athena_results_bucket_arn
}
module "meta" {
  source = "./meta"
}
