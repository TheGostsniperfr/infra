# Vault Secrets Operator Policy
path "${mount_path}/data/*" {
  capabilities = ["read"]
}
