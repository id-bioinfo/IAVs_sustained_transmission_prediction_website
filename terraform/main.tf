provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
        project = "sustained-transmission-yt"
    }
  }
}


module "acm_request_certificate" {
  source = "cloudposse/acm-request-certificate/aws"

  domain_name                       = "iav-transmission.com"
  subject_alternative_names         = ["www.iav-transmission.com"]
  zone_id                           = "Z0233205CD7F9FU3B348"
  process_domain_validation_options = true
  ttl                               = "300"
}

module "cdn" {
  source = "./modules/custom-s3-cloudfront-web"
  providers = {
    aws.aws = aws
    aws.us-east-1 = aws
  }

  namespace            = "d24h"
  stage                = "prod"
  name                 = "sustained-transmission-yt"
  aliases              = ["iav-transmission.com", "www.iav-transmission.com"]
  dns_alias_enabled    = true
  parent_zone_id       = "Z0233205CD7F9FU3B348"
  origin_force_destroy = true
  labels_as_tags = []

  website_enabled             = false
  http_version                = "http3"
  minimum_protocol_version    = "TLSv1.2_2021"
  allow_ssl_requests_only     = false        # Connection between cloudfront and S3 is HTTP

  acm_certificate_arn = module.acm_request_certificate.arn

  cloudfront_access_logging_enabled = false
  cloudfront_access_log_create_bucket = false

  s3_access_logging_enabled = false

  depends_on = [module.acm_request_certificate]
}

module "acm_request_certificate_org" {
  source = "cloudposse/acm-request-certificate/aws"

  domain_name                       = "iav-transmission.org"
  subject_alternative_names         = ["www.iav-transmission.org"]
  zone_id                           = "Z04532293P2OL5R9PCB1U"
  process_domain_validation_options = true
  ttl                               = "300"
}

module "cdn_org" {
  source = "./modules/custom-s3-cloudfront-web"
  providers = {
    aws.aws = aws
    aws.us-east-1 = aws
  }

  namespace            = "d24h"
  stage                = "prod"
  name                 = "sustained-transmission-yt"
  aliases              = ["iav-transmission.org", "www.iav-transmission.org"]
  dns_alias_enabled    = true
  parent_zone_id       = "Z04532293P2OL5R9PCB1U"
  origin_force_destroy = true
  origin_bucket = module.cdn.s3_bucket
  override_origin_bucket_policy = false

  website_enabled             = false
  http_version                = "http3"
  minimum_protocol_version    = "TLSv1.2_2021"
  allow_ssl_requests_only     = false        # Connection between cloudfront and S3 is HTTP

  acm_certificate_arn = module.acm_request_certificate_org.arn

  cloudfront_access_logging_enabled = false
  cloudfront_access_log_create_bucket = false

  s3_access_logging_enabled = false

  depends_on = [ module.acm_request_certificate_org, module.cdn ]
}
