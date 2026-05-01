resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.arffornia.id
  name                   = "groups"
  description            = "TODO"
  include_in_token_scope = true
  gui_order              = 1
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_mapper" {
  realm_id        = keycloak_realm.arffornia.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "group-mapper"
  claim_name      = "groups"
  full_path       = false # Output "admins" instead of "/admins"
}

resource "keycloak_openid_user_attribute_protocol_mapper" "picture_mapper" {
  realm_id         = keycloak_realm.arffornia.id
  client_id        = keycloak_openid_client.openid_client.id
  name             = "picture-mapper"
  user_attribute   = "picture"
  claim_name       = "picture"
  claim_value_type = "String"
}

resource "keycloak_openid_client_default_scopes" "openid_client_default_scopes" {
  realm_id  = keycloak_realm.arffornia.id
  client_id = keycloak_openid_client.openid_client.id
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.groups.name
  ]
}
