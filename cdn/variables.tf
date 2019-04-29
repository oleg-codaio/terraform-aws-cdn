data "aws_region" "current" {}

variable "name" {
  description = "Name identifying the created bucket and resources"
  default     = "root"
}

variable "zone_id" {
  description = "The ID of the Route 53 hosted zone within which to create this stack"
}

variable "acm_ssl_cert_arn" {
  description = "The ARN of the SSL certificate to be used by CloudFront"
}

variable "alert_sns_topic_arn" {
  description = "The ARN of the SNS topic to use for delivering health check alarms"
  default     = ""
}

variable "inaccessible_page_path" {
  description = "The path to the page to use for 404/403s"
  default     = "/error.html"
}
