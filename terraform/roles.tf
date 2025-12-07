resource "vault_kubernetes_auth_backend_role" "fixme_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "fixme-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.fixme_policy.name]
  audience                         = vault_kubernetes_auth_backend_config.kubernetes_auth.issuer
}