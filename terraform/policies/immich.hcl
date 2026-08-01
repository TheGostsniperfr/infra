# Immich Policy
path "${mount_path}/data/postgres/immich" {
  capabilities = ["read"]
}
path "${mount_path}/data/immich/secret-key" {
  capabilities = ["read"]
}
