# tfdash

This repo contains a collection of useful Terraform modules.

## cdn

CDN backed by an S3 bucket using CloudFront configured with SNI-based SSL.

```tf
module "cdn" {
  source                 = "github.com/vaskevich/tfdash//cdn"
  name                   = "my-cdn"
  zone_id                = "${aws_route53_zone.root.zone_id}"
  acm_ssl_cert_arn       = "${aws_acm_certificate.root.arn}"
  inaccessible_page_path = "/index.html"
}
```
