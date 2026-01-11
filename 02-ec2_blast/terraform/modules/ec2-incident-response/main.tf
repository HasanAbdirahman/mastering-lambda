provider "aws" {
  region = var.region
}

# 1️⃣ Quarantine Security Group (Black Hole)
resource "aws_security_group" "quarantine" {
  name        = var.quarantine_sg_name
  description = "Isolates compromised EC2 instances"
  vpc_id      = var.vpc_id
}

# 2️⃣ IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "security-remediator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:CreateSnapshot",
        "iam:GetInstanceProfile",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "logs:*"
      ]
      Resource = "*"
    }]
  })
}

# 3️⃣ Lambda Function
resource "aws_lambda_function" "remediator" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "remediator.lambda_handler"
  timeout       = 30
  filename      = "${path.module}/lambda/remediator.zip"

  environment {
    variables = {
      QUARANTINE_SG_ID = aws_security_group.quarantine.id
    }
  }
}

# 4️⃣ EventBridge Rule (GuardDuty)
resource "aws_cloudwatch_event_rule" "guardduty" {
  name = "guardduty-high-severity"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 8, 9]
    }
  })
}

# 5️⃣ EventBridge Target → Lambda
resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.guardduty.name
  arn  = aws_lambda_function.remediator.arn
}

# 6️⃣ Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty.arn
}
