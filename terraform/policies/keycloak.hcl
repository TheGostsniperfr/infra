# Keycloak Policy
path "${mount_path}/data/keycloak/db" {
  capabilities = ["read"]
}
path "${mount_path}/data/keycloak/admin" {
  capabilities = ["read"]
}
