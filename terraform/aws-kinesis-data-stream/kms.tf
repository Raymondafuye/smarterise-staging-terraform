
## kinesis service key
resource "aws_kms_key" "kinesis_service_key" {
  description             = "kinesis service key"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window

  policy = data.aws_iam_policy_document.kinesis_kms_key_policy.json
}

resource "aws_kms_alias" "service_key" {
  name          = "alias/kinesis_service_key"
  target_key_id = aws_kms_key.kinesis_service_key.key_id
}

data "aws_iam_policy_document" "kinesis_kms_key_policy" {

  statement {
    sid = "Allow Admin" # Root user will have permissions to manage the CMK, but do not have permissions to use the CMK in cryptographic operations. - https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#cryptographic-operations
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  statement {
    sid = "Allow Cryptography"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["kinesis.${var.region_name}.amazonaws.com"]
    }

  }

  statement {
    sid = "Allow logs access"

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.us-east-1.amazonaws.com"]
    }


    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:us-east-1:${var.account_id}:*"]
    }

  }

}
