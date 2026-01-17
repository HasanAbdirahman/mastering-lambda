
resource "aws_dynamodb_table" "metadata" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "VideoName"

  attribute {
    name = "VideoName"
    type = "S"
  }
}
