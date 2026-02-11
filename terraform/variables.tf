variable "k8s_host_url" {
  description = "The internal Kubernetes API server URL."
  type        = string
  default     = "https://kubernetes.default.svc.cluster.local"
}

variable "vault_url" {
  description = "The URL of the Vault server."
  type        = string
  default     = "https://vault.arffornia.com"
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
  default     = "arffornia.com"
}
