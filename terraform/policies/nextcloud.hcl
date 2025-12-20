# Nextcloud Policy
path "${mount_path}/data/postgres/nextcloud" {
  capabilities = ["read"]
}
path "${mount_path}/data/nextcloud/admin" {
  capabilities = ["read"]
}
