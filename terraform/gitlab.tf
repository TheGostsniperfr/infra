# -----------------------------------------------------------------------------
# GitLab: tenant groups and agents for Kubernetes
# -----------------------------------------------------------------------------
# Teams are the files k8s/config/gitlab-agents/teams/<team>.yaml (the name is the file name); the
# same files drive the ApplicationSet that deploys the agents (k8s/apps/gitlab-agents.yaml).
# Every team gets a GitLab group `apps/<team>` for its applications and its own agent, registered
# in `apps/platform/agent-<team>`. That project is outside the team's group on purpose: whoever can
# push to it can change the agent's config (which projects and branches may use it) or create a
# token for it. Only platform admins are members of `apps` and `apps/platform`; team members are
# added to `apps/<team>` only. GitLab requires the agent and the groups it authorizes to share the
# top-level group, hence `apps/platform` and not a separate top-level group.
# The agent's config (.gitlab/agents/<team>/config.yaml) is written here, so this repo stays the
# source of truth; GitLab only holds what Terraform pushes.
#
# One agent per team, not one per cluster: GitLab recommends a single agent with impersonation,
# but impersonation is Premium/Ultimate. On the free tier a CI job acts with the agent's own
# service account, so isolation between teams comes from separate agents whose service accounts
# only have rights in their team's namespaces (k8s/config/gitlab-agents).
# Feature: https://docs.gitlab.com/user/clusters/agent/
# Multi-tenancy: https://docs.gitlab.com/user/clusters/agent/install/#install-multiple-agents-in-your-cluster
# CI access: https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/
# Provider: https://registry.terraform.io/providers/gitlabhq/gitlab/19.5.0/docs

variable "gitlab_admin_token_var" {
  description = "Personal access token of a GitLab instance admin, scope api."
  type        = string
  sensitive   = true
}

locals {
  gitlab_teams_dir = "${path.module}/../k8s/config/gitlab-agents/teams"
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
  description      = "Agents for Kubernetes of every team. Platform admins only, managed by Terraform."
  visibility_level = "private"
}

resource "gitlab_group" "team" {
  for_each = local.gitlab_teams

  parent_id        = gitlab_group.apps.id
  name             = each.value.displayName
  path             = each.key
  visibility_level = "private"
}

resource "gitlab_project" "team_agent" {
  for_each = local.gitlab_teams

  namespace_id           = gitlab_group.platform.id
  name                   = "agent-${each.key}"
  path                   = "agent-${each.key}"
  description            = "Agent for Kubernetes of team ${each.key}. Managed by Terraform in the infra repo: do not edit here."
  visibility_level       = "private"
  initialize_with_readme = true
}

resource "gitlab_cluster_agent" "team" {
  for_each = local.gitlab_teams

  project = gitlab_project.team_agent[each.key].id
  name    = each.key
}

# protected_branches_only: only pipelines on protected branches (main, preprod) can use the agent
# https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/#restrict-access-to-the-agent-to-protected-branches
resource "gitlab_repository_file" "team_agent_config" {
  for_each = local.gitlab_teams

  project        = gitlab_project.team_agent[each.key].id
  branch         = gitlab_project.team_agent[each.key].default_branch
  file_path      = ".gitlab/agents/${each.key}/config.yaml"
  encoding       = "text"
  commit_message = "chore: update agent config from the infra repo"
  content = yamlencode({
    ci_access = {
      groups = [{
        id                      = gitlab_group.team[each.key].full_path
        protected_branches_only = true
      }]
    }
  })
}

resource "gitlab_cluster_agent_token" "team" {
  for_each = local.gitlab_teams

  project     = gitlab_project.team_agent[each.key].id
  agent_id    = gitlab_cluster_agent.team[each.key].agent_id
  name        = "terraform"
  description = "Read by agentk through Vault (kvv2/gitlab-agents/${each.key})."
}

resource "vault_kv_secret_v2" "gitlab_agent_token" {
  for_each = local.gitlab_teams

  mount = vault_mount.kvv2.path
  name  = "gitlab-agents/${each.key}"
  data_json = jsonencode({
    token = gitlab_cluster_agent_token.team[each.key].token
  })
}
