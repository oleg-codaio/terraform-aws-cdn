output "bucket_arn" {
  description = "The ARN of the created underlying S3 bucket"
  value       = aws_s3_bucket.root.arn
}

output "cloudfront_arn" {
  description = "The ARN of the created CloudFront distribution"
  value       = aws_cloudfront_distribution.root.arn
}

output "cloudfront_id" {
  description = "The ID of the created CloudFront distribution"
  value       = aws_cloudfront_distribution.root.id
}

