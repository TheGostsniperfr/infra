# n8n Policy
path "${mount_path}/data/n8n/encryption-key" {
  capabilities = ["read"]
}
path "${mount_path}/data/postgres/n8n" {
  capabilities = ["read"]
}
