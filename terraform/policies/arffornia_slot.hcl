# Arffornia test slot server (spec 016): the staging database and service account, and its own
# RCON password. Never a prod path.
path "${mount_path}/data/arffornia/staging/db" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/staging/svc" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/slot/server" {
  capabilities = ["read"]
}
