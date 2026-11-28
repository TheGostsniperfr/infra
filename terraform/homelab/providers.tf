# Proxmox: https://registry.terraform.io/providers/bpg/proxmox/0.124.0/docs
# Tailscale: https://registry.terraform.io/providers/tailscale/tailscale/0.30.0/docs

terraform {
  # Same Garage bucket and credentials as ../ (see ../Readme.md), separate key.
  backend "s3" {
    bucket = "tf-state"
    key    = "homelab/terraform.tfstate"
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
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.124.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.30.0"
    }
  }
}

# The API certificate is signed by the cluster CA in certs/, trusted through SSL_CERT_DIR
# (see README.md), so TLS stays verified.
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}
