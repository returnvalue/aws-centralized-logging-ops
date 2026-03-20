# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    route53        = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
    elb            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    rds            = "http://localhost:4566"
    autoscaling    = "http://localhost:4566"
    events         = "http://localhost:4566"
    logs           = "http://localhost:4566"
  }
}

# S3 Bucket: Persistent archival store for centralized logs
resource "aws_s3_bucket" "log_archive" {
  bucket = "centralized-log-archive-bucket"

  tags = {
    Name        = "centralized-log-archive"
    Environment = "SysOps-Lab"
  }
}

# IAM Role: Identity for the Kinesis Data Firehose delivery stream
resource "aws_iam_role" "firehose_role" {
  name = "centralized-logging-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "firehose-delivery-role"
    Environment = "SysOps-Lab"
  }
}

# IAM Policy: Grants Firehose permission to write log data to the S3 bucket
resource "aws_iam_role_policy" "firehose_s3_policy" {
  name = "firehose-s3-delivery-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
      }
    ]
  })
}

# Kinesis Data Firehose: The delivery pipeline for log data
resource "aws_kinesis_firehose_delivery_stream" "log_delivery_stream" {
  name        = "centralized-log-delivery-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.log_archive.arn

    # Optional: Configure prefixing for better log organization
    prefix              = "logs/year=!{timestamp:YYYY}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/year=!{timestamp:YYYY}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"
  }

  tags = {
    Name        = "centralized-log-firehose"
    Environment = "SysOps-Lab"
  }
}

# CloudWatch Log Group: The initial collection point for log data
resource "aws_cloudwatch_log_group" "central_log_group" {
  name              = "/aws/sysops-lab/centralized-logs"
  retention_in_days = 7

  tags = {
    Name        = "central-log-group"
    Environment = "SysOps-Lab"
  }
}

# IAM Role: Identity allowing CloudWatch Logs to push data to Firehose
resource "aws_iam_role" "cw_to_firehose_role" {
  name = "cw-to-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "cw-to-firehose-role"
    Environment = "SysOps-Lab"
  }
}

# IAM Policy: Specific permission for CloudWatch to 'put' data into the Firehose stream
resource "aws_iam_role_policy" "cw_to_firehose_policy" {
  name = "cw-to-firehose-policy"
  role = aws_iam_role.cw_to_firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.log_delivery_stream.arn
      }
    ]
  })
}

# Log Subscription Filter: Activates the stream from CloudWatch to Firehose
resource "aws_cloudwatch_log_subscription_filter" "firehose_log_filter" {
  name            = "central-firehose-log-filter"
  log_group_name  = aws_cloudwatch_log_group.central_log_group.name
  filter_pattern  = "" # Matches all log events
  destination_arn = aws_kinesis_firehose_delivery_stream.log_delivery_stream.arn
  role_arn        = aws_iam_role.cw_to_firehose_role.arn
}

# Outputs: Key identifiers for testing the centralized logging pipeline
output "log_group_name" {
  value = aws_cloudwatch_log_group.central_log_group.name
}

output "firehose_delivery_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.log_delivery_stream.arn
}

output "s3_archive_bucket" {
  value = aws_s3_bucket.log_archive.id
}
