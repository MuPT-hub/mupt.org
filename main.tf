# Run manually to provision the Pages project and GitHub Actions configuration.
# Site builds and uploads are handled separately by static-site-tools workflows.
# State is stored in an existing Cloudflare R2 bucket via its S3-compatible API.
# Supply the bucket name and account-specific R2 endpoint during init:
#   tofu init -backend-config='bucket=YOUR_R2_BUCKET' \
#     -backend-config='endpoints={s3="https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com"}'
# Authenticate R2 with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY containing
# R2 credentials with Object Read & Write access to the state bucket.
# Provider authentication still uses CLOUDFLARE_API_TOKEN and GITHUB_TOKEN.
# If migrating existing state, add -migrate-state to init.
terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # Upstream still allows all 5.x releases despite an account_token
      # breaking change: https://github.com/omsf/static-site-tools/issues/28
      version = "= 5.9.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    key                         = "mupt/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "cloudflare" {}

provider "github" {
  owner = "mupt-hub"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID (TF_VAR_cloudflare_account_id)."
}

variable "custom_domain" {
  type        = string
  description = "Optional custom domain. Leave empty to skip the Pages domain and DNS record."
  default     = ""

  validation {
    condition     = var.custom_domain == "" || can(regex("^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,63}$", var.custom_domain))
    error_message = "custom_domain must be empty or a fully qualified domain name without a scheme or trailing dot."
  }
}

locals {
  custom_domain_enabled = var.custom_domain != ""
}

# Look up the zone only when a custom domain has been configured.
data "cloudflare_zones" "this" {
  count = local.custom_domain_enabled ? 1 : 0

  name = var.custom_domain
  account = {
    id = var.cloudflare_account_id
  }
}

module "cloudflare" {
  source                  = "github.com/omsf/static-site-tools//modules/cloudflare_pages"
  cloudflare_token_name   = "mupt_token"
  cloudflare_project_name = "mupt"
  cloudflare_account_id   = var.cloudflare_account_id
}

module "github" {
  source                           = "github.com/omsf/static-site-tools//modules/github_vars"
  github_repository                = "mupt-hub/mupt.org"
  cloudflare_project_name_var_name = "CLOUDFLARE_PROJECT_NAME"
  cloudflare_project_name          = "mupt"
  cloudflare_account_id            = var.cloudflare_account_id
  cloudflare_token                 = module.cloudflare.cloudflare_token
}

resource "cloudflare_pages_domain" "this" {
  count = local.custom_domain_enabled ? 1 : 0

  account_id   = var.cloudflare_account_id
  project_name = "mupt"
  name         = var.custom_domain

  depends_on = [module.cloudflare]
}

# Cloudflare flattens the apex CNAME to the Pages project hostname.
resource "cloudflare_dns_record" "this" {
  count = local.custom_domain_enabled ? 1 : 0

  zone_id = data.cloudflare_zones.this[0].result[0].id
  name    = var.custom_domain
  type    = "CNAME"
  content = module.cloudflare.cloudflare_subdomain
  proxied = true
  ttl     = 1

  depends_on = [cloudflare_pages_domain.this]
}

output "subdomain" {
  value       = module.cloudflare.cloudflare_subdomain
  description = "Cloudflare Pages hostname for the site."
}
