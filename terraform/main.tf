#module "aws_athena" {
#  source                                          = "./aws-athena"
#  datalake_raw_athena_results_storage_bucket_name = var.datalake_raw_athena_results_storage_bucket_name
#  datalake_raw_database_name                      = var.datalake_raw_database_name
#}

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


# module "aws-lambda" {
#   source                                          = "./aws-lambda"
#   device_kinesis_data_stream_arn                  = module.aws_kinesis_data_stream.device_data_stream_arn
#   datalake_raw_bucket_arn                         = module.s3.datalake_raw_bucket_arn
#   datalake_raw_athena_results_bucket_arn          = module.s3.datalake_raw_athena_results_bucket_arn
#   parsed_device_kinesis_data_stream_arn           = module.aws_kinesis_data_stream.parsed_device_data_stream_arn
#   smart_deivce_to_rds_env_vars                    = { "CLUSTER_ARN" : module.rds.rds_cluster_arn, "SECRET_ARN" : module.rds.rds_cluster_secret_arn }
#   rds_cluster_arn                                 = module.rds.rds_cluster_arn
#   rds_cluster_secret_arn                          = module.rds.rds_cluster_secret_arn
#   #smart_device_to_s3_raw_lambda_function_env_vars = { "S3_RAW_BUCKET_NAME" : module.s3.datalake_raw_bucket_name, "DATABASE_RAW" : module.aws_athena.athena_raw_database, "PARSED_DEVICE_KINESIS_DATA_STREAM_NAME" : module.aws_kinesis_data_stream.parsed_device_data_stream_name }
#   connect_to_aurora_lambda_function_env_vars      = { "CLUSTER_ARN" : module.rds.rds_cluster_arn, "SECRET_ARN" : module.rds.rds_cluster_secret_arn }
# }

#I want to skip the athena setup for now
module "aws-lambda" {
  source                                          = "./aws-lambda"
  device_kinesis_data_stream_arn                  = module.aws_kinesis_data_stream.device_data_stream_arn
  datalake_raw_bucket_arn                         = module.s3.datalake_raw_bucket_arn
  datalake_raw_athena_results_bucket_arn          = module.s3.datalake_raw_athena_results_bucket_arn
  parsed_device_kinesis_data_stream_arn           = module.aws_kinesis_data_stream.parsed_device_data_stream_arn
  smart_deivce_to_rds_env_vars                    = { "DB_INSTANCE_ARN" : module.rds.rds_instance_arn, "SECRET_ARN" : module.rds.rds_credentials_secret_arn}
  rds_endpoint                                    = module.rds.rds_instance_endpoint
  rds_db_name                                     = module.rds.rds_instance_name
  rds_username                                    = module.rds.rds_instance_username
  rds_password                                    = module.rds.rds_instance_password
  rds_instance_arn                                = module.rds.rds_instance_arn
  rds_credentials_secret_arn                      = module.rds.rds_credentials_secret_arn
  smart_device_to_s3_raw_lambda_function_env_vars = {}
  connect_to_aurora_lambda_function_env_vars      = { "DB_INSTANCE_ARN" : module.rds.rds_instance_arn,"SECRET_ARN" : module.rds.rds_credentials_secret_arn}
  }

module "rds" {
  source              = "./aws-rds"
  public_subnets     = module.aws-vpc.public_subnets
  rds_postgresql_username = var.rds_postgresql_username
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
  rds_instance_arn                 = module.rds.rds_instance_arn
  rds_credentials_secret_arn       = module.rds.rds_credentials_secret_arn
  rds_connection_string_secret_arn = module.rds.rds_connection_string_secret_arn

}

module "aws-vpc" {
  source = "./aws-vpc"
  
  vpc_cidr_block       = "10.0.0.0/16"
  vpc_name            = "main"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  availability_zones   = ["eu-west-2a", "eu-west-2b"]  # Change these to match your region
}

module "aws-sagemaker" {
  source                                 = "./aws-sagemaker"
  datalake_raw_bucket_arn                = module.s3.datalake_raw_bucket_arn
  datalake_raw_athena_results_bucket_arn = module.s3.datalake_raw_athena_results_bucket_arn
}
module "meta" {
  source = "./meta"
}


#variable "alarm_names" {
#  default = jsondecode(file("${path.module}/alarms.json"))
#}


variable "alarms" {
  type = map(object({
    metric_name = string
    namespace   = string
  }))
  default = {
    Current_Unbalance_Factor_C362 = { metric_name = "CurrentUnbalanceFactor", namespace = "SmartMeterMetrics" }
    Current_Unbalance_Factor_Critical_Alert = { metric_name = "CurrentUnbalanceFactor", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C025 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C070 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C098 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C119 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C132 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C147 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C188 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C229 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C290 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C304 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C306 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C358 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C359 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C362 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C363 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_C615 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" } 
    DT_Overload_Alert_Critical_C025 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C070 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C098 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C119 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C132 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C147 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C188 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C229 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C290 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C304 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C306 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C358 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C359 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C362 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C363 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C407 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    DT_Overload_Alert_Critical_C615 = { metric_name = "CumulativeDTOverload", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C025  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C070  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C098  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C102  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C119  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C132  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C147  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C188  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C229  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C290  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C304  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C306  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C358  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C359  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C362  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C363  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C407  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Alert_C615  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C025  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C070  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C098  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C102  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C119  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C132  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C147  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C188  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C229  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C290  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C304  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C306  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C358  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C359  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C362  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C363  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C407  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    Voltage_PhaseA_Critical_Alert_C615  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }  
    Voltage_PhaseB_Alert_C025  = { metric_name = "VoltagePhase_B", namespace = "SmartMeterMetrics" }
    Voltage_PhaseB_Alert_C362  = { metric_name = "VoltagePhase_B", namespace = "SmartMeterMetrics" }
    Voltage_PhaseC_Alert_C362  = { metric_name = "VoltagePhase_C", namespace = "SmartMeterMetrics" }
    Voltage_PhaseB_Critical_Alert_C025  = { metric_name = "VoltagePhase_B", namespace = "SmartMeterMetrics" }
    Voltage_PhaseB_Critical_Alert_C362  = { metric_name = "VoltagePhase_B", namespace = "SmartMeterMetrics" }
    Voltage_PhaseC_Critical_Alert_C362 = { metric_name = "VoltagePhase_C", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C025 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C070 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C098 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C102 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C119 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C132 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C147 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C188 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C229 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C290 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C304 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C306 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C358 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C359 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C362 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C363 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C407 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_Alert_C615 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C025 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C070 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C098 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C102 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C119 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C132 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C147 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C188 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C229 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C290 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C304 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C306 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C358 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C359 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C362 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C363 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C407 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    Voltage_unbalance_alert_C615 = { metric_name = "VoltageUnbalanceCalculated", namespace = "SmartMeterMetrics" }
    voltage_phaseA_alert_C025  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C070"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C098"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C102"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C119"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C132"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C147"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C188"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C229"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C290"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C304"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C306"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C358"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C359"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
   # "voltage_phaseA_alert C362"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C363"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C407"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    "voltage_phaseA_alert C615"  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }  
    voltage_phaseA_critical_Alert_C025  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C070  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C098  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C102  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C119  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C132  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C147  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C188  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C229  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C290  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C304  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C306  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C358  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C359  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C362  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C363  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C407  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }
    voltage_phaseA_critical_Alert_C615  = { metric_name = "VoltagePhase_A", namespace = "SmartMeterMetrics" }  
    voltage_phaseB_alert = { metric_name = "VoltagePhaseB", namespace = "SmartMeterMetrics" }
    voltage_phaseB_alert_C025 = { metric_name = "VoltagePhaseB", namespace = "SmartMeterMetrics" }
    voltage_phaseB_alert_critical_C025 = { metric_name = "VoltagePhaseB", namespace = "SmartMeterMetrics" }
    voltage_phaseB_alert_critical_C362 = { metric_name = "VoltagePhaseB", namespace = "SmartMeterMetrics" }
    voltage_phaseC_alert = { metric_name = "VoltagePhaseC", namespace = "SmartMeterMetrics" }
    voltage_phaseC_critical_Alert_C362 = { metric_name = "VoltagePhaseC", namespace = "SmartMeterMetrics" }
    
  }
}

resource "aws_cloudwatch_metric_alarm" "alarms" {
  for_each = var.alarms
  alarm_name          = each.key
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = 300
  statistic           = "Average"
  threshold           = 3.0
  actions_enabled     = true
  alarm_actions       = ["arn:aws:sns:eu-west-2:368563411071:CloudWatchAlarmTopic"]
}


###SNS IMPORT
resource "aws_sns_topic" "alarm_topic" {
  name = "CloudWatchAlarmTopic"
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "lambda"
  endpoint  = "arn:aws:lambda:eu-west-2:794038252750:function:SNS_Alarm_Message_Trigger"
}

###ses configuration

module "aws_ses" {
  source                = "./aws_ses"
  domain_name           = "smarterise.com"
  email1                = "r.afuye@smarterise.com"
  email2                = "tech@smarterise.com"
  email3                = "t.falarunu@smarterise.com"
  configuration_set_name = "smarterise-config-set"
}

output "ses_identity_arn" {
  value = module.aws_ses.ses_identity_arn
}

output "dkim_tokens" {
  value = module.aws_ses.dkim_tokens
}

output "mail_from_domain" {
  value = module.aws_ses.mail_from_domain
}

output "ses_configuration_set" {
  value = module.aws_ses.ses_configuration_set
}





