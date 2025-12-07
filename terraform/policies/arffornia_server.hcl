# Arffornia Minecraft Servers (Arcane & Nexus) Policy
path "${mount_path}/data/postgres/arffornia" {
  capabilities = ["read"]
}
path "${mount_path}/data/postgres/luckperms" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/server" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/svc" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/proxy" {
  capabilities = ["read"]
}
path "${mount_path}/data/arffornia/discord-bot" {
  capabilities = ["read"]
}
