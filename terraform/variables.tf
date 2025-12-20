variable "k8s_host_url" {
  description = "The internal Kubernetes API server URL."
  type = string
  default = "https://kubernetes.default.svc.cluster.local"
}

variable "vault_url" {
    description = "The URL of the Vault server."
    type        = string
    default     = "https://vault.arffornia.com"
}