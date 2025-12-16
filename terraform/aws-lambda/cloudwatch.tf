
##############################
##### smart device to s3 #####
##############################
#resource "aws_cloudwatch_log_metric_filter" "smart_device_to_s3_error_filter" {
#  name           = "${module.smart_device_to_s3_raw_lambda_function.lambda_function_name}-error-filter"
#  pattern        = "\"[ERROR]\""
#  log_group_name = module.smart_device_to_s3_raw_lambda_function.lambda_cloudwatch_log_group_name

#  metric_transformation {
#    name          = "${module.smart_device_to_s3_raw_lambda_function.lambda_function_name}-error-count"
#    namespace     = "lambda"
#    value         = "1"
#    default_value = "0"
#  }
#}

# cloudwatch metric alarm
#resource "aws_cloudwatch_metric_alarm" "smart_device_to_s3_error_filter_alarm" {
#  alarm_name                = "${module.smart_device_to_s3_raw_lambda_function.lambda_function_name}-error-alarm"
#  comparison_operator       = "GreaterThanThreshold"
#  evaluation_periods        = "1"
#  metric_name               = lookup(aws_cloudwatch_log_metric_filter.smart_device_to_s3_error_filter.metric_transformation[0], "name")
#  namespace                 = "lambda"
#  period                    = "60"
#  statistic                 = "Sum"
#  threshold                 = "0"
#  alarm_description         = ""
#  insufficient_data_actions = []
#  treat_missing_data        = "notBreaching"
#}


##############################
##### smart device to RDS ####
##############################
#resource "aws_cloudwatch_log_metric_filter" "smart_device_to_rds_error_filter" {
#  name           = "${module.smart_device_to_rds_lambda_function.lambda_function_name}-error-filter"
#  pattern        = "\"[ERROR]\""
#  log_group_name = module.smart_device_to_rds_lambda_function.lambda_cloudwatch_log_group_name

#  metric_transformation {
#    name          = "${module.smart_device_to_rds_lambda_function.lambda_function_name}-error-count"
#    namespace     = "lambda"
#    value         = "1"
#    default_value = "0"
#  }
#}

# cloudwatch metric alarm
#resource "aws_cloudwatch_metric_alarm" "smart_device_to_rds_error_filter_alarm" {
#  alarm_name                = "${module.smart_device_to_rds_lambda_function.lambda_function_name}-error-alarm"
#  comparison_operator       = "GreaterThanThreshold"
#  evaluation_periods        = "1"
#  metric_name               = lookup(aws_cloudwatch_log_metric_filter.smart_device_to_rds_error_filter.metric_transformation[0], "name")
#  namespace                 = "lambda"
#  period                    = "60"
#  statistic                 = "Sum"
#  threshold                 = "0"
#  alarm_description         = ""
#  insufficient_data_actions = []
#  treat_missing_data        = "notBreaching"
#}


##############################
####### invoke-ml-model ######
##############################
#resource "aws_cloudwatch_log_metric_filter" "invoke_ml_model_error_filter" {
#  name           = "${module.invoke_ml_model.lambda_function_name}-error-filter"
#  pattern        = "\"[ERROR]\""
#  log_group_name = module.invoke_ml_model.lambda_cloudwatch_log_group_name

#  metric_transformation {
#    name          = "${module.invoke_ml_model.lambda_function_name}-error-count"
#    namespace     = "lambda"
#    value         = "1"
#    default_value = "0"
#  }
#}

# cloudwatch metric alarm
#resource "aws_cloudwatch_metric_alarm" "invoke_ml_model_error_filter_alarm" {
#  alarm_name                = "${module.invoke_ml_model.lambda_function_name}-error-alarm"
#  comparison_operator       = "GreaterThanThreshold"
#  evaluation_periods        = "1"
#  metric_name               = lookup(aws_cloudwatch_log_metric_filter.invoke_ml_model_error_filter.metric_transformation[0], "name")
#  namespace                 = "lambda"
#  period                    = "60"
#  statistic                 = "Sum"
#  threshold                 = "0"
#  alarm_description         = ""
#  insufficient_data_actions = []
#  treat_missing_data        = "notBreaching"
#}

