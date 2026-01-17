
module "s3" {
  source      = "../../modules/s3"
  bucket_name = "raw-media-uploads-prod"
}

module "dynamodb" {
  source     = "../../modules/dynamodb"
  table_name = "MediaMetadata"
}
