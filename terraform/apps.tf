# -----------------------------------------------------------------------------
# Platform: applications of the teams (k8s/config/app-platform/teams/<team>.yaml, key `apps`)
# -----------------------------------------------------------------------------
# For every app: GitLab group apps/<team>/<app> with a backend and a frontend project forked from
# the templates and a `deploy` project, a key in Vault that only the pipelines on `main` of the
# app can sign images with, a Keycloak client with the roles member and manager, and the name
# <app>-<team>.arffornia.com. Argo CD deploys what `deploy` holds; its namespace, database,
# Argo CD project and Kyverno rules come from the ApplicationSet (charts/platform-team).
# Guide: k8s/config/app-platform/GUIDE.md. Security model: k8s/config/app-platform/SECURITY.md.
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

  # Not secret: what the pipelines of apps/<team>/<app> need to sign and release
  gitlab_app_variables = merge([
    for key, a in local.gitlab_apps : {
      "${key}/DEPLOY_REPO"     = { app = key, name = "DEPLOY_REPO", value = "gitlab.${var.base_domain}/apps/${a.team}/${a.app}/deploy.git" }
      "${key}/VAULT_ADDR"      = { app = key, name = "VAULT_ADDR", value = var.vault_url }
      "${key}/VAULT_SIGN_ROLE" = { app = key, name = "VAULT_SIGN_ROLE", value = "sign-${a.namespace}" }
      "${key}/SIGNING_KEY"     = { app = key, name = "SIGNING_KEY", value = "hashivault://apps-${a.namespace}" }
    }
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

# --- GitLab: shared CI ---
# The jobs every component runs after its tests (check deploy.yaml, build, sign, release), as a
# CI/CD component the apps include at a version: a fix is one tag here and a version bump there,
# instead of an edit in every fork. Teams read it (include needs read access), only platform
# admins change it, and only they create its version tags.
# Feature: https://docs.gitlab.com/ci/components/

resource "gitlab_project" "platform_ci" {
  namespace_id     = gitlab_group.platform.id
  name             = "ci"
  path             = "ci"
  description      = "CI/CD components of the app platform, included by every app at a version. Platform admins only."
  visibility_level = "private"
}

resource "gitlab_tag_protection" "platform_ci" {
  project             = gitlab_project.platform_ci.id
  tag                 = "*"
  create_access_level = "maintainer"
}

resource "gitlab_project_share_group" "platform_ci" {
  for_each = local.gitlab_teams

  project      = gitlab_project.platform_ci.id
  group_id     = gitlab_group.team[each.key].id
  group_access = "reporter"
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

# Kubelet pulls the team's images, and Kyverno their signatures, with this token (read_registry on
# apps/<team> only)
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

# --- GitLab: deploy repositories, read by Argo CD ---

# One values file per component (charts/app), written by the component's pipeline on main. No CI
# here. `main` is protected by default: only Maintainers and that pipeline push to it.
resource "gitlab_project" "app_deploy" {
  for_each = local.gitlab_apps

  namespace_id           = gitlab_group.app[each.key].id
  name                   = "deploy"
  path                   = "deploy"
  description            = "What Argo CD deploys: <component>.yaml per component, written by its pipeline on main. Revert a commit to roll back."
  visibility_level       = "private"
  initialize_with_readme = true
  builds_access_level    = "disabled"
}

# Lets the release job push to `deploy`. Not the trust boundary: an image runs only if the app's
# key signed it (Kyverno), and only a pipeline on main can use that key.
resource "gitlab_project_access_token" "app_deploy" {
  for_each = local.gitlab_apps

  project      = gitlab_project.app_deploy[each.key].id
  name         = "release"
  description  = "Release jobs of apps/${each.key}: group CI variable DEPLOY_REPO_TOKEN."
  scopes       = ["write_repository"]
  access_level = "maintainer"
  rotation_configuration = {
    expiration_days    = 365
    rotate_before_days = 30
  }
}

# Protected: branch and merge request pipelines never see it. Hidden: not even Maintainers can
# read it back from the settings.
resource "gitlab_group_variable" "app_deploy_token" {
  for_each = local.gitlab_apps

  group     = gitlab_group.app[each.key].id
  key       = "DEPLOY_REPO_TOKEN"
  value     = gitlab_project_access_token.app_deploy[each.key].token
  protected = true
  masked    = true
  hidden    = true
}

# Argo CD reads the deploy repositories with this token (read_repository on apps/<team>)
resource "gitlab_group_deploy_token" "team_repo" {
  for_each = local.gitlab_teams

  group  = gitlab_group.team[each.key].id
  name   = "argocd-read"
  scopes = ["read_repository"]
}

resource "vault_kv_secret_v2" "team_repo" {
  for_each = local.gitlab_teams

  mount = vault_mount.kvv2.path
  name  = "gitlab-agents/${each.key}-repo"
  data_json = jsonencode({
    username = gitlab_group_deploy_token.team_repo[each.key].username
    password = gitlab_group_deploy_token.team_repo[each.key].token
  })
}

# --- Vault: image signing ---
# cosign signs through Vault transit: the private key never leaves Vault. A pipeline logs in
# with its GitLab id_token, and the role only accepts one from a protected `main` of the app's
# group: a branch, a merge request or a laptop cannot sign. Kyverno checks the signature with
# the public key (charts/platform-team, guardrails.yaml).
# cosign and Vault: https://github.com/sigstore/cosign/blob/main/KMS.md#hashicorp-vault
# GitLab id_tokens: https://docs.gitlab.com/ci/secrets/id_token_authentication/

resource "vault_mount" "transit" {
  path        = "transit"
  type        = "transit"
  description = "Signing keys of the apps' images, never exported"
}

resource "vault_transit_secret_backend_key" "app_signing" {
  for_each = local.gitlab_apps

  backend    = vault_mount.transit.path
  name       = "apps-${each.value.namespace}"
  type       = "ecdsa-p256"
  exportable = false
}

resource "vault_kv_secret_v2" "app_signing_public_key" {
  for_each = local.gitlab_apps

  mount = vault_mount.kvv2.path
  name  = "gitlab-agents/${each.value.namespace}-cosign"
  data_json = jsonencode({
    "cosign.pub" = vault_transit_secret_backend_key.app_signing[each.key].keys[vault_transit_secret_backend_key.app_signing[each.key].latest_version - 1].public_key
  })
}

resource "vault_jwt_auth_backend" "gitlab" {
  description        = "GitLab CI id_tokens, for the apps' pipelines"
  path               = "gitlab"
  type               = "jwt"
  oidc_discovery_url = "https://gitlab.${var.base_domain}"
  bound_issuer       = "https://gitlab.${var.base_domain}"
}

resource "vault_policy" "app_signing" {
  for_each = local.gitlab_apps

  name   = "sign-${each.value.namespace}"
  policy = <<-EOT
    # Pipelines on main of apps/${each.key}: sign with the app's key, nothing else
    path "${vault_mount.transit.path}/sign/apps-${each.value.namespace}" {
      capabilities = ["update"]
    }
    path "${vault_mount.transit.path}/sign/apps-${each.value.namespace}/*" {
      capabilities = ["update"]
    }
    path "${vault_mount.transit.path}/keys/apps-${each.value.namespace}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_jwt_auth_backend_role" "app_signing" {
  for_each = local.gitlab_apps

  backend         = vault_jwt_auth_backend.gitlab.path
  role_name       = "sign-${each.value.namespace}"
  role_type       = "jwt"
  bound_audiences = [var.vault_url]
  user_claim      = "user_login"
  # Maintainers can protect other branches: `ref` pins the role to main itself
  bound_claims_type = "string"
  bound_claims = {
    namespace_path = "apps/${each.key}"
    ref            = "main"
    ref_type       = "branch"
    ref_protected  = "true"
  }
  token_policies = [vault_policy.app_signing[each.key].name]
  token_ttl      = 300
  token_max_ttl  = 600
}

# --- Vault: secrets of the apps ---
# The Vault Secrets Operator reads every VaultSecret with its own service account; the role a
# VaultSecret names is what limits it. Kyverno only lets the app's namespace name this role.

resource "vault_policy" "app_secrets" {
  for_each = local.gitlab_apps

  name   = "apps-${each.value.namespace}"
  policy = <<-EOT
    # VaultSecrets of namespace ${each.value.namespace}: the app's secrets and the team's pull token
    path "${vault_mount.kvv2.path}/data/apps/${each.key}" {
      capabilities = ["read"]
    }
    path "${vault_mount.kvv2.path}/data/gitlab-agents/${each.value.team}-registry" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "app_secrets" {
  for_each = local.gitlab_apps

  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "apps-${each.value.namespace}"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400
  token_policies                   = [vault_policy.app_secrets[each.key].name]
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
