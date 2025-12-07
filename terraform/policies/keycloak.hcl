# Keycloak Policy
path "${mount_path}/data/postgres/keycloak" {
  capabilities = ["read"]
}
path "${mount_path}/data/keycloak/admin" {
  capabilities = ["read"]
}
path "${mount_path}/data/keycloak/epinaloa-realm-secret" {
  capabilities = ["read"]
}
