#### Create the S3 bucket ####

resource "aws_s3_bucket" "ssm_s3_bucket" {
  bucket              = "${var.s3_bucket}-${data.aws_caller_identity.current.id}-${data.aws_region.current.name}"
  object_lock_enabled = true
  tags = {
    name     = "ssm-logs"
    DataType = "SENSITIVE"
  }
}

#### Configure server side encryption with SSE-S3 ####

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encrypt" {
  bucket = aws_s3_bucket.ssm_s3_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#### Enable versioning on the bucket ####

resource "aws_s3_bucket_versioning" "versioning_s3" {
  bucket = aws_s3_bucket.ssm_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

#### Configure block public access policies on the bucket ####

resource "aws_s3_bucket_public_access_block" "block_public_s3" {
  bucket = aws_s3_bucket.ssm_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#### Enable server side logging on the S3 bucket ####

resource "aws_s3_bucket_logging" "server_logs" {
  bucket = aws_s3_bucket.ssm_s3_bucket.id

  target_bucket = var.s3_log_bucket_id
  target_prefix = "servers-logs/"
}