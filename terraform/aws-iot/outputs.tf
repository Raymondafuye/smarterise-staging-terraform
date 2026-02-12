output "iot_kinesis_role_arn" {
  description = "ARN of the IAM role for IoT to write to Kinesis"
  value       = var.enable_kinesis_integration ? aws_iam_role.iot_core_write_to_kinesis_device_stream_role[0].arn : ""
}
