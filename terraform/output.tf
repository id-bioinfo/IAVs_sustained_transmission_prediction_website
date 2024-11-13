output "frontend_s3_bucket" {
  description = "S3 bucket name for storing the frontend website content"
  value       = module.cdn.s3_bucket
}

output "frontend_s3_bucket_log" {
  description = "S3 bucket for storing the frontend website logs"
  value       = module.cdn.logs
}