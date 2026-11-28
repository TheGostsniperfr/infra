variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.1.49:8006/"
}

variable "proxmox_node" {
  type    = string
  default = "proxmox"
}

# terraform@pve!homelab, format "terraform@pve!homelab=<uuid>". See README.md for its role.
variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

# OAuth client with the scopes policy_file and auth_keys, allowed to use tag:subnet-router.
variable "tailscale_oauth_client_id" {
  type      = string
  sensitive = true
}

variable "tailscale_oauth_client_secret" {
  type      = string
  sensitive = true
}

# Built by the dotfiles flake into .edge-template (gitignored), see README.md.
# Only read when the template file is created.
variable "edge_template_path" {
  type    = string
  default = ".edge-template/tarball/nixos-edge.tar.xz"
}
