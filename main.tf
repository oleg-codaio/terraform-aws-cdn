/**
 * Instantiates an S3-based CloudFront distribution on a given subdomain.
 */

provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  version = "~> 3.0"
}

data "aws_route53_zone" "root" {
  zone_id = var.zone_id
}

locals {
  s3_origin_id  = "S3-${var.name}"
  zone_domain   = replace(data.aws_route53_zone.root.name, "/\\.$/", "")
  domain_name   = "${var.name != "root" ? "${var.name}." : ""}${local.zone_domain}"
  bucket_prefix = "${replace(local.zone_domain, "/\\W/", "-")}-${data.aws_region.current.name}"
}

// Create an S3 bucket to hold these assets.

resource "aws_s3_bucket" "root" {
  bucket = "${local.bucket_prefix}-${var.name}-assets"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "Static assets for ${var.name}"
  }
}

// Set up an SSL-enabled CloudFront distribution.

resource "aws_cloudfront_distribution" "root" {
  origin {
    domain_name = aws_s3_bucket.root.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.root.cloudfront_access_identity_path
    }
  }

  comment             = var.name
  aliases             = [local.domain_name]
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_ssl_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  custom_error_response {
    error_code            = "403"
    error_caching_min_ttl = "300"
    response_code         = "404"
    response_page_path    = var.inaccessible_page_path
  }

  custom_error_response {
    error_code            = "404"
    error_caching_min_ttl = "300"
    response_code         = "404"
    response_page_path    = var.inaccessible_page_path
  }
}

resource "aws_cloudfront_origin_access_identity" "root" {
}

// Set up a policy to grant bucket access to CloudFront.

resource "aws_s3_bucket_policy" "root" {
  bucket = aws_s3_bucket.root.id
  policy = data.aws_iam_policy_document.root.json
}

data "aws_iam_policy_document" "root" {
  policy_id = "RootPolicy"

  statement {
    sid       = "GrantCdnReadAccess"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.root.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.root.iam_arn]
    }
  }
}

// Set up the subdomain DNS record.

resource "aws_route53_record" "root" {
  name    = "${local.domain_name}."
  type    = "A"
  zone_id = var.zone_id

  alias {
    name                   = aws_cloudfront_distribution.root.domain_name
    zone_id                = aws_cloudfront_distribution.root.hosted_zone_id
    evaluate_target_health = true
  }
}

// Set up a health check for the subdomain as well as a CloudWatch alarm.

resource "aws_route53_health_check" "root" {
  count             = var.alert_sns_topic_arn != "" ? 1 : 0
  type              = "HTTPS"
  fqdn              = aws_route53_record.root.fqdn
  port              = 443
  measure_latency   = true
  request_interval  = 30
  failure_threshold = 2
  enable_sni        = true

  tags = {
    Name = "Health check for ${aws_route53_record.root.name}"
  }
}

// NOTE: S3 CloudWatch metrics are only supported in us-east-1.
resource "aws_cloudwatch_metric_alarm" "health" {
  count                     = var.alert_sns_topic_arn != "" ? 1 : 0
  provider                  = aws.us-east-1
  alarm_name                = "${var.name}-alarm-health-check"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HealthCheckStatus"
  namespace                 = "AWS/Route53"
  period                    = "600"
  statistic                 = "Minimum"
  threshold                 = "1"
  alarm_actions             = [var.alert_sns_topic_arn]
  ok_actions                = [var.alert_sns_topic_arn]
  insufficient_data_actions = [var.alert_sns_topic_arn]
  alarm_description         = "Send an alert if ${var.name} is down"

  dimensions = {
    HealthCheckId = aws_route53_health_check.root[0].id
  }
}

