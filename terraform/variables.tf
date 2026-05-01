variable "k8s_host_url" {
  description = "The internal Kubernetes API server URL."
  type        = string
  default     = "https://kubernetes.default.svc.cluster.local"
}

variable "vault_url" {
  description = "The URL of the Vault server."
  type        = string
  default     = "https://vault.arffornia.fr"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone Id of Arffornia Record"
  type        = string
  default     = "dc1899399ee7cfada2dde29d967dccdd"
}

variable "dc_ip" {
  description = "The public IP address of the homelab network."
  type        = string
  default     = "176.186.130.237"
}

variable "domain_name" {
  description = "The domain name for the Arffornia Cluster."
  type        = string
  default     = "arffornia.fr"
}

# -----------------------------------------------------------------------------
# Keycloak Variables
# -----------------------------------------------------------------------------

variable "keycloak_url" {
  description = "The Base URL of the Keycloak instance"
  type        = string
  default     = "https://auth.arffornia.fr"
}

variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "base_domain" {
  description = "Base domain for the lab"
  type        = string
  default     = "arffornia.fr"
}
