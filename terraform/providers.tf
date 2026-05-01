# Doc: https://registry.terraform.io/providers/hashicorp/vault/5.6.0/docs

terraform {
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
  client_id                = "admin-cli"
  url                      = var.keycloak_url
  username                 = var.keycloak_admin_username
  password                 = var.keycloak_admin_password
  tls_insecure_skip_verify = false # Set to true if using self-signed certs
}

provider "vault" {
  address = var.vault_url
  # token   = "" # Set in environment variable VAULT_TOKEN or ~/.vault-token file (if both are unset)
  # ca_cert_file = "" # Path to CA cert file if using self-signed certs
}

provider "cloudflare" {
  # Configuration options
}
