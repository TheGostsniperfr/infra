# Arffornia Velocity Proxy Policy
path "${mount_path}/data/arffornia/proxy" {
  capabilities = ["read"]
}
path "${mount_path}/data/postgres/luckperms" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/svc-proxy" {
  capabilities = ["read"]
}
