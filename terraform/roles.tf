# resource "vault_kubernetes_auth_backend_role" "fixme_role" {
#   backend                          = vault_auth_backend.kubernetes.path
#   role_name                        = "fixme-role"
#   bound_service_account_names      = ["vault-secrets-operator"]
#   bound_service_account_namespaces = ["vault-secrets-operator"]
#   token_ttl                        = 86400 # 24h
#   token_policies                   = [vault_policy.fixme_policy.name]
#   audience                         = vault_kubernetes_auth_backend_config.kubernetes_auth.issuer
# }

# -----------------------------------------------------------------------------
# Arffornia Roles (Grouped)
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "arffornia_proxy_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "arffornia-proxy-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.arffornia_proxy_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "arffornia_server_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "arffornia-server-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.arffornia_server_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "arffornia_website_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "arffornia-website-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.arffornia_website_policy.name]
}

# -----------------------------------------------------------------------------
# Adminer Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "adminer_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "adminer-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.adminer_policy.name]
}

# -----------------------------------------------------------------------------
# CSI Driver SMB Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "csi_driver_smb_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "csi-driver-smb-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.csi_driver_smb_policy.name]
}

# -----------------------------------------------------------------------------
# Keycloak Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "keycloak_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "keycloak-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.keycloak_policy.name]
}

# -----------------------------------------------------------------------------
# Longhorn Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "longhorn_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "longhorn-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.longhorn_policy.name]
}

# -----------------------------------------------------------------------------
# Minio S3 Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "minio_s3_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "minio-s3-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.minio_s3_policy.name]
}

# -----------------------------------------------------------------------------
# Monitoring Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "monitoring_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "monitoring-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.monitoring_policy.name]
}

# -----------------------------------------------------------------------------
# N8n Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "n8n_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "n8n-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.n8n_policy.name]
}

# -----------------------------------------------------------------------------
# Nextcloud Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "nextcloud_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "nextcloud-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.nextcloud_policy.name]
}

# -----------------------------------------------------------------------------
# Plex Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "plex_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "plex-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.plex_policy.name]
}

# -----------------------------------------------------------------------------
# Postgres Operator Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "postgres_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "postgres-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.postgres_policy.name]
}

# -----------------------------------------------------------------------------
# Vaultwarden Role
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "vaultwarden_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vaultwarden-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.vaultwarden_policy.name]
}

# -----------------------------------------------------------------------------
# Operator Roles
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "vault_secrets_operator_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-secrets-operator-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.vault_secrets_operator_policy.name]
}

# -----------------------------------------------------------------------------
# Cert-Manager Roles
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "cert_manager_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "cert-manager-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.cert_manager_policy.name]
}

# -----------------------------------------------------------------------------
# Coder Roles
# -----------------------------------------------------------------------------

resource "vault_kubernetes_auth_backend_role" "coder_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "coder-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400
  token_policies                   = [vault_policy.coder_policy.name]
}
