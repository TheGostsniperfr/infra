# Doc: https://registry.terraform.io/providers/hashicorp/vault/5.6.0/docs

terraform {
  backend "s3" {
    bucket         = "arffornia-infra-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.10.1"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.22.0"
    }

    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.8.0"
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
