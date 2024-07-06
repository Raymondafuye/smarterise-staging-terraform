resource "aws_kinesis_stream" "device_data_stream" {
  name                      = var.kinesis_device_data_stream_name
  retention_period          = var.retention_period
  enforce_consumer_deletion = var.enforce_consumer_deletion
  shard_count               = 1
  #reference for recommended cloudwatch metrics: https://docs.aws.amazon.com/streams/latest/dev/monitoring-with-cloudwatch.html#kinesis-metric-use
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "IncomingRecords",
    "IteratorAgeMilliseconds",
    "OutgoingRecords",
    "ReadProvisionedThroughputExceeded",
    "WriteProvisionedThroughputExceeded",
  ]
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis_service_key.key_id
}

resource "aws_kinesis_stream" "parsed_device_data_stream" {
  name                      = var.parsed_device_data_stream
  retention_period          = var.retention_period
  enforce_consumer_deletion = var.enforce_consumer_deletion
  shard_count               = 1
  #reference for recommended cloudwatch metrics: https://docs.aws.amazon.com/streams/latest/dev/monitoring-with-cloudwatch.html#kinesis-metric-use
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "IncomingRecords",
    "IteratorAgeMilliseconds",
    "OutgoingRecords",
    "ReadProvisionedThroughputExceeded",
    "WriteProvisionedThroughputExceeded",
  ]
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis_service_key.key_id
}
