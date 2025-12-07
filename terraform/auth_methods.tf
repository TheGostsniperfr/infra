resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes_auth" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.k8s_host_url
  # kubernetes_ca_cert     = "" # TODO Check the goal of CA cert configuration
  # token_reviewer_jwt     = "" # TODO Check the goal of token reviewer JWT configuration
  issuer                 = var.k8s_host_url
  disable_iss_validation = "true"
}