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
    "https://longhorn.${var.base_domain}/oauth2/callback",
    "https://adminer.${var.base_domain}/oauth2/callback",
    "http://localhost:3000/api/auth/callback/keycloak"
  ]

  valid_post_logout_redirect_uris = [
    "https://longhorn.${var.base_domain}/",
    "https://adminer.${var.base_domain}/",
    "http://localhost:3000/"
  ]

  web_origins = [
    "https://longhorn.${var.base_domain}",
    "https://adminer.${var.base_domain}",
    "http://localhost:3000/"
  ]
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

# -----------------------------------------------------------------------------
# OIDC CLIENT: GitLab
# -----------------------------------------------------------------------------
resource "keycloak_openid_client" "gitlab" {
  realm_id                     = keycloak_realm.arffornia.id
  client_id                    = "gitlab"
  name                         = "GitLab"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://gitlab.${var.base_domain}/users/auth/openid_connect/callback"
  ]

  valid_post_logout_redirect_uris = [
    "https://gitlab.${var.base_domain}/"
  ]
}

resource "keycloak_openid_client_default_scopes" "gitlab_scopes" {
  realm_id  = keycloak_realm.arffornia.id
  client_id = keycloak_openid_client.gitlab.id
  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.groups.name
  ]
}

# -----------------------------------------------------------------------------
# OIDC CLIENT: Grafana
# -----------------------------------------------------------------------------
resource "keycloak_openid_client" "grafana" {
  realm_id                     = keycloak_realm.arffornia.id
  client_id                    = "grafana"
  name                         = "Grafana"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  pkce_code_challenge_method   = "S256"

  valid_redirect_uris = [
    "https://grafana.${var.base_domain}/login/generic_oauth"
  ]

  valid_post_logout_redirect_uris = [
    "https://grafana.${var.base_domain}/login"
  ]

  web_origins = [
    "https://grafana.${var.base_domain}"
  ]
}

resource "keycloak_openid_client_default_scopes" "grafana_scopes" {
  realm_id  = keycloak_realm.arffornia.id
  client_id = keycloak_openid_client.grafana.id
  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.groups.name
  ]
}
