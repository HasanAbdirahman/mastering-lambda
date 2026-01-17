
output "bucket_name" {
  value = aws_s3_bucket.clean_logs.bucket
}

output "lambda_name" {
  value = aws_lambda_function.scrubber.function_name
}
