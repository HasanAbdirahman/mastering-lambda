
resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = var.role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  filename      = var.zip_path
}
