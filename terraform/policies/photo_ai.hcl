# photo-ai Policy
path "${mount_path}/data/photo-ai/discord" {
  capabilities = ["read"]
}
path "${mount_path}/data/photo-ai/runner" {
  capabilities = ["read"]
}
path "${mount_path}/data/postgres/photoai" {
  capabilities = ["read"]
}
