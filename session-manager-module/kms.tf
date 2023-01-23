#### Create a KMS key to encrypt the CloudWatch Log Group and encrypt data in transit ####

data "aws_iam_policy_document" "ssm_kms_access" {
  statement {
    sid = "KMSPolicyAllowIAMManageAccess"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid = "AllowCloudWatchLogsKMS"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt*",
      "kms:Describe*",
      "kms:Encrypt*",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "ssm_access_key" {
  description             = "Key used to grant access for ssm logs"
  policy                  = data.aws_iam_policy_document.ssm_kms_access.json
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "ssm_key_alias" {
  name = "alias/kms/ssm-key"
  target_key_id = aws_kms_key.ssm_access_key.id
}

