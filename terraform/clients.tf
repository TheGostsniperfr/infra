# -----------------------------------------------------------------------------
# OIDC CLIENT: Arffornia OpenID Client (for Envoy Gateway Auth)
# -----------------------------------------------------------------------------
resource "keycloak_openid_client" "arffornia_openid_client" {
  realm_id  = keycloak_realm.arffornia.id
  client_id = "arffornia-openid"

  name    = "Arffornia OpenID Client"
  enabled = true

  access_type                               = "CONFIDENTIAL"
  standard_flow_enabled                     = true
  direct_access_grants_enabled              = false
  implicit_flow_enabled                     = false
  service_accounts_enabled                  = false
  standard_token_exchange_enabled           = false
  oauth2_device_authorization_grant_enabled = false

  valid_redirect_uris = [
    "https://*.${var.base_domain}/oauth2/callback"
  ]

  valid_post_logout_redirect_uris = [
    "https://*.${var.base_domain}/"
  ]

  web_origins = [
    "https://*.${var.base_domain}"
  ]

  authentication_flow_binding_overrides {
    browser_id = keycloak_authentication_flow.browser_openid_client.id
  }
}

# -----------------------------------------------------------------------------
# OIDC CLIENT: ArgoCD
# -----------------------------------------------------------------------------
resource "keycloak_openid_client" "argocd" {
  realm_id                     = keycloak_realm.arffornia.id
  client_id                    = "argocd"
  name                         = "ArgoCD"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://argocd.${var.base_domain}/auth/callback"
  ]

  valid_post_logout_redirect_uris = [
    "https://argocd.${var.base_domain}/"
  ]
}

resource "keycloak_openid_client_default_scopes" "argocd_scopes" {
  realm_id  = keycloak_realm.arffornia.id
  client_id = keycloak_openid_client.argocd.id
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.groups.name
  ]
}

# -----------------------------------------------------------------------------
# OIDC CLIENT: Vault
# -----------------------------------------------------------------------------
resource "keycloak_openid_client" "vault" {
  realm_id                     = keycloak_realm.arffornia.id
  client_id                    = "vault"
  name                         = "Vault"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://vault.${var.base_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  authentication_flow_binding_overrides {
    browser_id = keycloak_authentication_flow.browser_openid_client.id
  }
}

resource "keycloak_openid_client_default_scopes" "vault_scopes" {
  realm_id  = keycloak_realm.arffornia.id
  client_id = keycloak_openid_client.vault.id
  default_scopes = [
    "profile",
    "email",
    "groups"
  ]
}
