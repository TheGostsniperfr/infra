path "${mount_path}/data/coder/config" {
  capabilities = ["read"]
}
path "${mount_path}/data/postgres/coder" {
  capabilities = ["read"]
}
