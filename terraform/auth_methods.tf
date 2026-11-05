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

# Role used by `vault login -method=oidc` and the UI. It was created by hand; the import block
# brings it under Terraform. Before the first apply, compare with
# `vault read auth/oidc/role/default`: the plan must only add max_age.
# Docs: https://developer.hashicorp.com/vault/api-docs/auth/jwt#create-update-role
import {
  to = vault_jwt_auth_backend_role.oidc_default
  id = "auth/oidc/role/default"
}

resource "vault_jwt_auth_backend_role" "oidc_default" {
  backend        = vault_jwt_auth_backend.keycloak.path
  role_name      = "default"
  role_type      = "oidc"
  user_claim     = "preferred_username"
  groups_claim   = "groups"
  token_policies = ["default"]

  bound_audiences = [keycloak_openid_client.vault.client_id]
  allowed_redirect_uris = [
    "https://vault.${var.base_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]

  # Step-up: Keycloak re-authenticates when the last login is older than 5 minutes, so every
  # Vault login asks for a fresh passkey touch even inside a 30-day remember-me session.
  max_age = 300
}
