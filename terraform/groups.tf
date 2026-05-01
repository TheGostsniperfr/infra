resource "keycloak_group" "infra" {
  realm_id = keycloak_realm.arffornia.id
  name     = "infra"
}

resource "keycloak_group" "member" {
  realm_id = keycloak_realm.arffornia.id
  name     = "member"
}
