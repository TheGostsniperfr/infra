# -----------------------------------------------------------------------------
# GitLab: tenant groups
# -----------------------------------------------------------------------------
# Teams are the files k8s/config/app-platform/teams/<team>.yaml (the name is the file name); the
# same files drive the ApplicationSet that deploys the teams' apps (k8s/apps/app-platform-teams.yaml).
# Every team gets a GitLab group `apps/<team>` for its applications. Only platform admins are
# members of `apps` and `apps/platform`; team members are added to `apps/<team>` only.
# No GitLab agent for Kubernetes: pipelines never reach the cluster, Argo CD pulls instead.
# Why: k8s/config/app-platform/SECURITY.md
# Provider: https://registry.terraform.io/providers/gitlabhq/gitlab/19.5.0/docs

variable "gitlab_admin_token_var" {
  description = "Personal access token of a GitLab instance admin, scope api."
  type        = string
  sensitive   = true
}

locals {
  gitlab_teams_dir = "${path.module}/../k8s/config/app-platform/teams"
  gitlab_teams = {
    for f in fileset(local.gitlab_teams_dir, "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.gitlab_teams_dir}/${f}"))
  }
}

# Top-level groups are created by Terraform only: a user's own group would be a namespace outside
# `apps`, with its own runners settings and visibility, that no one reviews.
# https://docs.gitlab.com/administration/settings/account_and_limit_settings/#prevent-new-users-from-creating-top-level-groups
resource "gitlab_application_settings" "this" {
  can_create_group = false
}

resource "gitlab_group" "apps" {
  name             = "Apps"
  path             = "apps"
  description      = "Applications deployed on the homelab cluster, one subgroup per team."
  visibility_level = "private"
}

resource "gitlab_group" "platform" {
  parent_id        = gitlab_group.apps.id
  name             = "Platform"
  path             = "platform"
  description      = "Templates and shared CI of the app platform. Platform admins only, managed by Terraform."
  visibility_level = "private"
}

resource "gitlab_group" "team" {
  for_each = local.gitlab_teams

  parent_id        = gitlab_group.apps.id
  name             = each.value.displayName
  path             = each.key
  visibility_level = "private"
}
