# -----------------------------------------------------------------------------
# Platform: applications of the teams (k8s/config/gitlab-agents/teams/<team>.yaml, key `apps`)
# -----------------------------------------------------------------------------
# For every app: GitLab group apps/<team>/<app> with a backend and a frontend project forked from
# the templates, the CI variables its pipelines need, a Keycloak client with the roles member and
# manager, and the name <app>-<team>.arffornia.com. Its namespace, database and RBAC come from the
# ApplicationSet (charts/gitlab-team). Guide: k8s/config/gitlab-agents/GUIDE.md.
# Templates are custom project templates on Premium; here they are plain projects that every
# component is forked from.

locals {
  gitlab_templates = {
    backend  = "quarkus-backend"
    frontend = "react-frontend"
  }

  gitlab_apps = merge([
    for team, t in local.gitlab_teams : {
      for app, a in try(t.apps, {}) : "${team}/${app}" => {
        team      = team
        app       = app
        database  = try(a.database, false)
        roles     = try(a.roles, {})
        host      = "${app}-${team}.${var.base_domain}"
        namespace = "${team}-${app}"
        client_id = "${team}-${app}"
      }
    }
  ]...)

  gitlab_app_components = {
    for pair in setproduct(keys(local.gitlab_apps), keys(local.gitlab_templates)) :
    "${pair[0]}/${pair[1]}" => { app = pair[0], component = pair[1] }
  }

  gitlab_app_roles = {
    for pair in setproduct(keys(local.gitlab_apps), ["member", "manager"]) :
    "${pair[0]}/${pair[1]}" => { app = pair[0], role = pair[1] }
  }

  # Not secret: what the pipelines of apps/<team>/<app> need to deploy
  gitlab_app_variables = merge([
    for key, a in local.gitlab_apps : merge(
      {
        "${key}/KUBE_CONTEXT"   = { app = key, name = "KUBE_CONTEXT", value = "apps/platform/agent-${a.team}:${a.team}" }
        "${key}/APP_NAMESPACE"  = { app = key, name = "APP_NAMESPACE", value = a.namespace }
        "${key}/APP_HOST"       = { app = key, name = "APP_HOST", value = a.host }
        "${key}/OIDC_ISSUER"    = { app = key, name = "OIDC_ISSUER", value = "https://auth.${var.base_domain}/realms/${keycloak_realm.arffornia.realm}" }
        "${key}/OIDC_CLIENT_ID" = { app = key, name = "OIDC_CLIENT_ID", value = a.client_id }
      },
      a.database ? {
        "${key}/DB_SECRET" = { app = key, name = "DB_SECRET", value = "app.${a.app}-db.credentials.postgresql.acid.zalan.do" }
        "${key}/DB_HOST"   = { app = key, name = "DB_HOST", value = "${a.app}-db" }
      } : {}
    )
  ]...)
}

# --- GitLab: templates ---

resource "gitlab_group" "templates" {
  parent_id        = gitlab_group.platform.id
  name             = "Templates"
  path             = "templates"
  description      = "Starting point of every app component. Platform admins only."
  visibility_level = "private"
}

resource "gitlab_project" "template" {
  for_each = local.gitlab_templates

  namespace_id     = gitlab_group.templates.id
  name             = each.value
  path             = each.value
  description      = "Template of the ${each.key} of an app, forked into apps/<team>/<app>/${each.key}."
  visibility_level = "private"
}

# --- GitLab: apps ---

resource "gitlab_group" "app" {
  for_each = local.gitlab_apps

  parent_id        = gitlab_group.team[each.value.team].id
  name             = each.value.app
  path             = each.value.app
  visibility_level = "private"
}

resource "gitlab_project" "app_component" {
  for_each = local.gitlab_app_components

  namespace_id           = gitlab_group.app[each.value.app].id
  name                   = each.value.component
  path                   = each.value.component
  visibility_level       = "private"
  forked_from_project_id = gitlab_project.template[each.value.component].id
  # Merge requests of the app target the app itself, never the template
  mr_default_target_self = true

  lifecycle {
    # Created once from the template; the team owns the code afterwards
    ignore_changes = [forked_from_project_id]
  }
}

resource "gitlab_group_variable" "app" {
  for_each = local.gitlab_app_variables

  group = gitlab_group.app[each.value.app].id
  key   = each.value.name
  value = each.value.value
}

# Kubelet pulls the team's images with this token (read_registry on apps/<team> only)
resource "gitlab_group_deploy_token" "team_registry" {
  for_each = local.gitlab_teams

  group  = gitlab_group.team[each.key].id
  name   = "registry-pull"
  scopes = ["read_registry"]
}

resource "vault_kv_secret_v2" "team_registry" {
  for_each = local.gitlab_teams

  mount = vault_mount.kvv2.path
  name  = "gitlab-agents/${each.key}-registry"
  data_json = jsonencode({
    username = gitlab_group_deploy_token.team_registry[each.key].username
    password = gitlab_group_deploy_token.team_registry[each.key].token
  })
}

# --- Keycloak: one public client per app (SPA with PKCE), roles in the token ---

resource "keycloak_openid_client" "app" {
  for_each = local.gitlab_apps

  realm_id                     = keycloak_realm.arffornia.id
  client_id                    = each.value.client_id
  name                         = "${each.value.app} (${each.value.team})"
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  pkce_code_challenge_method   = "S256"

  valid_redirect_uris             = ["https://${each.value.host}/*"]
  valid_post_logout_redirect_uris = ["https://${each.value.host}/*"]
  web_origins                     = ["https://${each.value.host}"]
}

resource "keycloak_openid_client_default_scopes" "app" {
  for_each = local.gitlab_apps

  realm_id       = keycloak_realm.arffornia.id
  client_id      = keycloak_openid_client.app[each.key].id
  default_scopes = ["profile", "email", "roles", "web-origins"]
}

# The backend checks that the token was issued for this app
resource "keycloak_openid_audience_protocol_mapper" "app" {
  for_each = local.gitlab_apps

  realm_id                 = keycloak_realm.arffornia.id
  client_id                = keycloak_openid_client.app[each.key].id
  name                     = "audience"
  included_client_audience = each.value.client_id
  add_to_access_token      = true
  add_to_id_token          = false
}

resource "keycloak_role" "app" {
  for_each = local.gitlab_app_roles

  realm_id  = keycloak_realm.arffornia.id
  client_id = keycloak_openid_client.app[each.value.app].id
  name      = each.value.role
}

resource "keycloak_group" "app_role" {
  for_each = local.gitlab_app_roles

  realm_id = keycloak_realm.arffornia.id
  name     = "app-${local.gitlab_apps[each.value.app].client_id}-${each.value.role}s"
}

resource "keycloak_group_roles" "app_role" {
  for_each = local.gitlab_app_roles

  realm_id = keycloak_realm.arffornia.id
  group_id = keycloak_group.app_role[each.key].id
  role_ids = [keycloak_role.app[each.key].id]
}

resource "keycloak_group_memberships" "app_role" {
  for_each = local.gitlab_app_roles

  realm_id = keycloak_realm.arffornia.id
  group_id = keycloak_group.app_role[each.key].id
  members  = try(local.gitlab_apps[each.value.app].roles[each.value.role], [])
}

# --- DNS ---

resource "cloudflare_dns_record" "app" {
  for_each = local.gitlab_apps

  zone_id = var.cloudflare_zone_id
  name    = "${each.value.app}-${each.value.team}"
  type    = "CNAME"
  content = "origin.${var.domain_name}"
  ttl     = 1
  proxied = true
}
