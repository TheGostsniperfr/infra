# Arffornia staging website (spec 016): staging values only, never a prod path.
path "${mount_path}/data/arffornia/staging/website" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/staging/db" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/staging/svc" {
  capabilities = ["read"]
}
