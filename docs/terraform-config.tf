# Terraform Configuration for Project 1: S3 + Lambda + SNS
# By: Islam Zain
# This file provisions all AWS resources needed for the image thumbnail generation project

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Project1-ImageThumbnails"
      Environment = "Development"
      ManagedBy   = "Terraform"
      CreatedBy   = "Islam Zain"
    }
  }
}

# ============================================================================
# VARIABLES
# ============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "project1"
}

variable "thumbnail_size" {
  description = "Thumbnail size in pixels (width x height)"
  type        = string
  default     = "200x200"
}

variable "sns_email" {
  description = "Email address for SNS notifications"
  type        = string
  sensitive   = true
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ============================================================================
# S3 BUCKETS
# ============================================================================

# Source bucket for original images
resource "aws_s3_bucket" "source_images" {
  bucket = "${var.project_name}-images-source-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-images-source"
    Description = "Source bucket for original images"
  }
}

# Destination bucket for thumbnails
resource "aws_s3_bucket" "destination_thumbnails" {
  bucket = "${var.project_name}-thumbnails-dest-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-thumbnails-dest"
    Description = "Destination bucket for thumbnail images"
  }
}

# Block public access to both buckets
resource "aws_s3_bucket_public_access_block" "source_pab" {
  bucket = aws_s3_bucket.source_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "dest_pab" {
  bucket = aws_s3_bucket.destination_thumbnails.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for disaster recovery
resource "aws_s3_bucket_versioning" "source_versioning" {
  bucket = aws_s3_bucket.source_images.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "dest_versioning" {
  bucket = aws_s3_bucket.destination_thumbnails.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "source_sse" {
  bucket = aws_s3_bucket.source_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dest_sse" {
  bucket = aws_s3_bucket.destination_thumbnails.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# SNS TOPIC AND SUBSCRIPTION
# ============================================================================

resource "aws_sns_topic" "image_processing" {
  name              = "${var.project_name}-image-processing"
  display_name      = "${var.project_name} Image Processing Notifications"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project_name}-sns-topic"
    Description = "SNS topic for image processing notifications"
  }
}

resource "aws_sns_topic_policy" "image_processing_policy" {
  arn = aws_sns_topic.image_processing.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.image_processing.arn
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.image_processing.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.image_processing.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# ============================================================================
# IAM ROLE AND POLICIES FOR LAMBDA
# ============================================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-s3-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-role"
  }
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.source_images.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.destination_thumbnails.arn}/*"
      }
    ]
  })
}

# Custom policy for SNS access
resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "${var.project_name}-lambda-sns-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.image_processing.arn
      }
    ]
  })
}

# ============================================================================
# LAMBDA LAYER FOR PILLOW
# ============================================================================

# Note: This assumes you have a layer zip file locally
# To create: mkdir python/lib/python3.9/site-packages
#           pip install Pillow -t python/lib/python3.9/site-packages/
#           zip -r pillow-layer.zip python/

resource "aws_lambda_layer_version" "pillow" {
  # Uncomment if you have the layer file locally
  # filename   = "pillow-layer.zip"
  # layer_name = "${var.project_name}-pillow-layer"
  # source_code_hash = filebase64sha256("pillow-layer.zip")
  # compatible_runtimes = ["python3.9", "python3.10", "python3.11", "python3.12"]
  
  # For now, we'll use the AWS managed Python Image Processing layer
  # Comment out the below if using local layer

  lifecycle {
    ignore_changes = all
  }
}

# ============================================================================
# LAMBDA FUNCTION
# ============================================================================

resource "aws_lambda_function" "thumbnail_generator" {
  filename      = "lambda_function.zip"
  function_name = "${var.project_name}-thumbnail-generator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      THUMBNAIL_BUCKET = aws_s3_bucket.destination_thumbnails.bucket
      SNS_TOPIC_ARN    = aws_sns_topic.image_processing.arn
    }
  }

  source_code_hash = filebase64sha256("lambda_function.zip")

  # Uncomment to add Pillow layer if you created it
  # layers = [aws_lambda_layer_version.pillow.arn]

  tags = {
    Name = "${var.project_name}-lambda-function"
  }

  depends_on = [
    aws_iam_role_policy.lambda_s3_policy,
    aws_iam_role_policy.lambda_sns_policy,
    aws_iam_role_policy_attachment.lambda_logs
  ]
}

# ============================================================================
# S3 EVENT NOTIFICATION (TRIGGER)
# ============================================================================

resource "aws_s3_bucket_notification" "source_notification" {
  bucket = aws_s3_bucket.source_images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".jpg,.jpeg,.png"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail_generator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_images.arn
}

# ============================================================================
# CLOUDWATCH LOG GROUP
# ============================================================================

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.thumbnail_generator.function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# ============================================================================
# CLOUDWATCH ALARMS
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda function has errors"

  dimensions = {
    FunctionName = aws_lambda_function.thumbnail_generator.function_name
  }

  alarm_actions = [aws_sns_topic.image_processing.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-lambda-duration"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 25000 # 25 seconds in milliseconds
  alarm_description   = "Alert when Lambda function exceeds expected duration"

  dimensions = {
    FunctionName = aws_lambda_function.thumbnail_generator.function_name
  }

  alarm_actions = [aws_sns_topic.image_processing.arn]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "source_bucket_name" {
  value       = aws_s3_bucket.source_images.bucket
  description = "Name of the source S3 bucket for images"
}

output "destination_bucket_name" {
  value       = aws_s3_bucket.destination_thumbnails.bucket
  description = "Name of the destination S3 bucket for thumbnails"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.image_processing.arn
  description = "ARN of the SNS topic for notifications"
}

output "lambda_function_name" {
  value       = aws_lambda_function.thumbnail_generator.function_name
  description = "Name of the Lambda function"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.thumbnail_generator.arn
  description = "ARN of the Lambda function"
}

output "lambda_role_arn" {
  value       = aws_iam_role.lambda_role.arn
  description = "ARN of the Lambda execution role"
}

output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.lambda_logs.name
  description = "Name of the CloudWatch log group"
}