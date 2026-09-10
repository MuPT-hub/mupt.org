terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 5.9.0"
    }
  }
}

provider "cloudflare" {}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account that will own the R2 state bucket."
}

variable "bucket_name" {
  type        = string
  description = "Name of the R2 bucket used by the OpenTofu S3 backend."

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters containing only lowercase letters, numbers, and internal hyphens."
  }
}

resource "cloudflare_r2_bucket" "tfstate" {
  account_id    = var.cloudflare_account_id
  name          = var.bucket_name
  location      = "enam"
  storage_class = "Standard"
}

output "bucket_name" {
  value       = cloudflare_r2_bucket.tfstate.name
  description = "Bucket name to pass to the root configuration's S3 backend."
}

output "s3_endpoint" {
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
  description = "Account-specific R2 S3 endpoint to pass to the root configuration's S3 backend."
}
