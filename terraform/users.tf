#  ADMIN USER
# resource "keycloak_user" "admin_user" {
#   realm_id       = keycloak_realm.arffornia.id
#   username       = "admin"
#   enabled        = true
#   email          = "admin@arffornia.fr"
#   email_verified = true
#   first_name     = "Admin"
#   last_name      = "User"

#   initial_password {
#     value     = "Admin123!"
#     temporary = false
#   }
# }
# resource "keycloak_user_groups" "admin_user_groups" {
#   realm_id  = keycloak_realm.arffornia.id
#   user_id   = keycloak_user.admin_user.id
#   group_ids = [keycloak_group.admin.id]
# }

# USERS
locals {
  team_members = {
    "admin" = { first = "Admin", last = "User", email = "admin@arffornia.fr", is_infra = true }
    "brian" = { first = "Brian", last = "Perret", email = "brianperret.pro@gmail.com", is_infra = true }
  }
}

resource "random_password" "team" {
  for_each = local.team_members

  length  = 16
  special = true
}

resource "keycloak_user" "team" {
  for_each       = local.team_members
  realm_id       = keycloak_realm.arffornia.id
  username       = each.key
  email          = each.value.email
  first_name     = each.value.first
  last_name      = each.value.last
  enabled        = true
  email_verified = true

  required_actions = ["UPDATE_PASSWORD", "CONFIGURE_TOTP"]

  initial_password {
    value     = random_password.team[each.key].result
    temporary = true
  }

  lifecycle {
    ignore_changes = [
      required_actions,
      initial_password,
      attributes
    ]
  }
}

resource "keycloak_user_groups" "team_groups" {
  for_each = local.team_members
  realm_id = keycloak_realm.arffornia.id
  user_id  = keycloak_user.team[each.key].id

  group_ids = each.value.is_infra ? [
    keycloak_group.member.id,
    keycloak_group.infra.id
    ] : [
    keycloak_group.member.id
  ]
}

output "initial_passwords" {
  value = {
    for k, v in random_password.team :
    k => v.result
  }

  sensitive = true
}
