variable "aws_access_key" {
  type        = string
  description = "The AWS user access key"
  default     = "us-east-1"
}

variable "aws_secret_key" {
  type        = string
  description = "The AWS user secret"
}

variable "cloudflare_email" {
  type        = string
  description = "The Cloudflare user email"
  default     = "us-east-1"
}

variable "cloudflare_api_key" {
  type        = string
  description = "The Cloudflare user API key"
}


variable "cloudflare_zone_id" {
  type        = string
  description = "The Cloudflare domain zone ID"
}

variable "site_domain" {
  type        = string
  description = "The domain name to use for the static site"
}

variable "cache_policy_name" {
  type        = string
  description = "The CDN cache policy"
  default     = "Managed-CachingDisabled"
}
