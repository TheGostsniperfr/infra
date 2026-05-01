resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes_auth" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = var.k8s_host_url
  # kubernetes_ca_cert     = "" # TODO Check the goal of CA cert configuration
  # token_reviewer_jwt     = "" # TODO Check the goal of token reviewer JWT configuration
  issuer                 = var.k8s_host_url
  disable_iss_validation = "true"
}

# -----------------------------------------------------------------------------
# OIDC Auth Backend for Vault
# -----------------------------------------------------------------------------
resource "vault_jwt_auth_backend" "keycloak" {
  description        = "OIDC backend via Keycloak"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "${var.keycloak_url}/realms/${keycloak_realm.arffornia.realm}"
  oidc_client_id     = keycloak_openid_client.vault.client_id
  oidc_client_secret = keycloak_openid_client.vault.client_secret
  default_role       = "default"
}
