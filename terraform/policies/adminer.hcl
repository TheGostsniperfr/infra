# Adminer Policy
path "${mount_path}/data/adminer/basic-auth" {
  capabilities = ["read"]
}

path "${mount_path}/data/adminer/envoy-auth" {
  capabilities = ["read"]
}
