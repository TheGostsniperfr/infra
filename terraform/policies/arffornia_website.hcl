# Arffornia Website Policy
path "${mount_path}/data/arffornia/website" {
  capabilities = ["read"]
}
path "${mount_path}/data/postgres/arffornia" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/svc-proxy" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/svc" {
  capabilities = ["read"]
}
