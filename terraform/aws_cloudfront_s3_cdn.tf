# AWS CloudFront CDN & S3 Origin Terraform Module

resource "aws_s3_bucket" "cdn_bucket" {
  bucket        = "enterprise-devops-assets-cdn-bucket"
  force_destroy = false

  tags = {
    Name        = "Enterprise CDN Asset Storage"
    Environment = "production"
  }
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "enterprise-s3-oac"
  description                       = "OAC for CloudFront to S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn_distribution" {
  origin {
    domain_name              = aws_s3_bucket.cdn_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-enterprise-assets"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-enterprise-assets"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
