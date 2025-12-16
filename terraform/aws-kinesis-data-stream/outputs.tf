output "device_data_stream_name" {
  value = aws_kinesis_stream.device_data_stream.name
}

output "device_data_stream_arn" {
  value = aws_kinesis_stream.device_data_stream.arn
}

output "kinesis_kms_key_arn" {
  value = aws_kms_key.kinesis_service_key.arn
}
output "parsed_device_data_stream_name" {
  value = aws_kinesis_stream.parsed_device_data_stream.name
}

output "parsed_device_data_stream_arn" {
  value = aws_kinesis_stream.parsed_device_data_stream.arn
}