###########################################################
# Things
###########################################################
resource "aws_iot_thing_type" "smart_device" {
  name = var.smart_device_type
}

resource "aws_iot_thing_group" "accuenergy_device_group" {
  name = var.accuenergy_device_group_name
}

resource "aws_iot_thing" "smart_devices" {
  for_each = toset(var.smart_device_names)
  name     = each.value
  attributes = {
    thing_type_name = aws_iot_thing_type.smart_device.name
  }
}

resource "aws_iot_thing_group_membership" "accuenergy_device_group_membership" {
  for_each         = toset(var.smart_device_names)
  thing_name       = each.value
  thing_group_name = aws_iot_thing_group.accuenergy_device_group.name
  depends_on       = [aws_iot_thing.smart_devices]
}

###########################################################
# Policies
###########################################################
resource "aws_iot_policy" "smart_device_policy" {
  name = var.smart_device_polcy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iot:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

###########################################################
# Certificates
###########################################################
resource "aws_iot_certificate" "smart_device_cert" {
  for_each = toset(var.smart_device_names)
  active   = true
}

resource "aws_iot_policy_attachment" "smart_device_cert_policy_attachment" {
  for_each = toset(var.smart_device_names)
  policy   = aws_iot_policy.smart_device_policy.name
  target   = aws_iot_certificate.smart_device_cert[each.key].arn
}

resource "aws_iot_thing_principal_attachment" "smart_device_cert_attachment" {
  for_each  = toset(var.smart_device_names)
  principal = aws_iot_certificate.smart_device_cert[each.key].arn
  thing     = each.value
}

resource "aws_s3_object" "smart_device_cert_s3_object" {
  for_each       = toset(var.smart_device_names)
  bucket         = var.iot_device_certificate_bucket_name
  key            = "${each.value}_certificate_pem.crt"
  content_base64 = base64encode(aws_iot_certificate.smart_device_cert[each.key].certificate_pem)
}

resource "aws_s3_object" "smart_device_public_key_s3_object" {
  for_each       = toset(var.smart_device_names)
  bucket         = var.iot_device_certificate_bucket_name
  key            = "${each.value}_public_key.pem.key"
  content_base64 = base64encode(aws_iot_certificate.smart_device_cert[each.key].public_key)
}

resource "aws_s3_object" "smart_device_private_key_s3_object" {
  for_each       = toset(var.smart_device_names)
  bucket         = var.iot_device_certificate_bucket_name
  key            = "${each.value}_private_key.pem.key"
  content_base64 = base64encode(aws_iot_certificate.smart_device_cert[each.key].private_key)
}

###########################################################
# Kinesis Routing
###########################################################
resource "aws_iam_role" "iot_core_write_to_kinesis_device_stream_role" {
  name = "iot_core_write_to_kinesis_device_stream_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "write_to_kinesis_device_stream_policy" {
  name = "write_to_kinesis_device_stream_policy"
  role = aws_iam_role.iot_core_write_to_kinesis_device_stream_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["kinesis:PutRecord"]
        Effect   = "Allow"
        Resource = var.device_data_stream_arn
      },
      {
        Action   = ["kms:GenerateDataKey"]
        Effect   = "Allow"
        Resource = var.kinesis_kms_key_arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "write_to_kinesis_device_data_stream_role" {
  for_each    = toset(var.smart_device_names)
  name        = "write_to_kinesis_data_stream_${each.value}"
  description = "Example rule"
  enabled     = true
  sql         = "SELECT * FROM 'accuenergy/${each.value}'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn      = aws_iam_role.iot_core_write_to_kinesis_device_stream_role.arn
    stream_name   = var.device_data_stream_name
    partition_key = each.value
  }
}