# Vaultwarden Policy
path "${mount_path}/data/postgres/vaultwarden" {
  capabilities = ["read"]
}
path "${mount_path}/data/vaultwarden/admin" {
  capabilities = ["read"]
}
