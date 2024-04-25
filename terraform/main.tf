terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "2.19.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "aws_s3_bucket" "site" {
  bucket = var.site_domain
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "site" {
  bucket = aws_s3_bucket.site.id

  acl = "public-read"
  depends_on = [
    aws_s3_bucket_ownership_controls.site,
    aws_s3_bucket_public_access_block.site
  ]
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.site.arn,
          "${aws_s3_bucket.site.arn}/*",
        ]
      },
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.site
  ]
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.site_domain
  subject_alternative_names = ["*.${var.site_domain}"]
  validation_method         = "DNS"

  tags = {
    Name = var.site_domain
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = aws_acm_certificate.cert.arn
}

data "cloudflare_zones" "domain" {
  filter {
    name = var.site_domain
  }
}

resource "cloudflare_record" "acm" {
  zone_id = var.cloudflare_zone_id

  // Cloudflare doesn't support `allow_overwrite` field like the route53_record 
  // resource; as a result, this configuration hardcodes the first record to 
  // verify the ACM certificate.
  // for_each = {
  //   for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
  //     name   = dvo.resource_record_name
  //     record = dvo.resource_record_value
  //     type   = dvo.resource_record_type
  //   }
  // }

  name  = aws_acm_certificate.cert.domain_validation_options.*.resource_record_name[0]
  type  = aws_acm_certificate.cert.domain_validation_options.*.resource_record_type[0]
  value = trimsuffix(aws_acm_certificate.cert.domain_validation_options.*.resource_record_value[0], ".")

  // Must be set to false. ACM validation false otherwise
  proxied = false
}

data "aws_cloudfront_cache_policy" "cache_policy" {
  name = var.cache_policy_name
}

// This configuration uses Cloudfront defaults
// Cloudfront is required for static site hosting with S3 if bucket name is
// already taken.
resource "aws_cloudfront_distribution" "dist" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.site.website_endpoint
    origin_id   = aws_s3_bucket.site.id
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled             = true
  default_root_object = "index.html"

  aliases = [
    var.site_domain, "www.${var.site_domain}"
  ]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.site.id
    cache_policy_id        = data.aws_cloudfront_cache_policy.cache_policy.id
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method  = "sni-only"
  }
}

resource "cloudflare_record" "site_cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.site_domain
  value   = aws_cloudfront_distribution.dist.domain_name
  type    = "CNAME"

  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = aws_cloudfront_distribution.dist.domain_name
  type    = "CNAME"

  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "redirect_to_naked" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.site_domain}"
  value   = var.site_domain
  type    = "CNAME"

  ttl     = 1
  proxied = false
}
