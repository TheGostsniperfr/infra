# Doc: https://registry.terraform.io/providers/hashicorp/vault/5.6.0/docs

terraform {
  backend "s3" {
    bucket = "tf-state"
    key    = "infra/terraform.tfstate"
    region = "garage"
    endpoints = {
      s3 = "https://s3.arffornia.com"
    }
    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
  }
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.16.0"
    }

    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.7.0"
    }
  }
}

provider "keycloak" {
  client_id = "admin-cli"
  url       = var.keycloak_url
  # url                      = "http://localhost:8080"
  username                 = var.keycloak_admin_user_var
  password                 = var.keycloak_admin_password_var
  tls_insecure_skip_verify = false # Set to true if using self-signed certs
}

provider "vault" {
  address = var.vault_url
  # address = "http://localhost:8200"
  # token   = "" # Set in environment variable VAULT_TOKEN or ~/.vault-token file (if both are unset)
  # ca_cert_file = "" # Path to CA cert file if using self-signed certs
}

provider "cloudflare" {
  # Configuration options
  api_token = var.cloudflare_api_token_secret_var
}
