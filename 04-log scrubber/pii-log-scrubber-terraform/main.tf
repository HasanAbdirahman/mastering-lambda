
terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "clean_logs" {
  bucket = var.clean_log_bucket
}

resource "aws_iam_role" "lambda_role" {
  name = "api-log-scrubber-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "s3_write" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject"]
      Resource = "arn:aws:s3:::${var.clean_log_bucket}/*"
    }]
  })
}

resource "aws_lambda_function" "scrubber" {
  function_name = "api-log-scrubber"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"
  filename      = "${path.module}/lambda.zip"

  environment {
    variables = {
      CLEAN_LOG_BUCKET = var.clean_log_bucket
    }
  }
}

resource "aws_cloudwatch_log_group" "demo_app" {
  name              = "/aws/lambda/demo-app"
  retention_in_days = 1
}

resource "aws_lambda_permission" "allow_logs" {
  statement_id  = "AllowCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scrubber.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.demo_app.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "pii_filter" {
  name            = "pii-scrubber-filter"
  log_group_name  = aws_cloudwatch_log_group.demo_app.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.scrubber.arn
}
