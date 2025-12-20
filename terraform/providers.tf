# Doc: https://registry.terraform.io/providers/hashicorp/vault/5.6.0/docs

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.6.0"
    }
  }
}

provider "vault" {
  address = var.vault_url
  # token   = "" # Set in environment variable VAULT_TOKEN or ~/.vault-token file (if both are unset)
  # ca_cert_file = "" # Path to CA cert file if using self-signed certs
}
