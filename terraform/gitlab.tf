# -----------------------------------------------------------------------------
# GitLab: tenant groups and agents for Kubernetes
# -----------------------------------------------------------------------------
# Every team gets a GitLab group `apps/<team>` for its applications and its own agent, registered
# in `apps/<team>/k8s-agent`. The agent's config (.gitlab/agents/<team>/config.yaml) is written
# here, so this repo stays the source of truth; GitLab only holds what Terraform pushes.
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
  # namespaces: Kubernetes namespaces the team's agent may deploy to (RBAC in k8s/config/gitlab-agents/teams/<team>)
  gitlab_teams = {
    demo = {
      name       = "Demo"
      namespaces = ["demo-sandbox"]
    }
  }
}

resource "gitlab_group" "apps" {
  name             = "Apps"
  path             = "apps"
  description      = "Applications deployed on the homelab cluster, one subgroup per team."
  visibility_level = "private"
}

resource "gitlab_group" "team" {
  for_each = local.gitlab_teams

  parent_id        = gitlab_group.apps.id
  name             = each.value.name
  path             = each.key
  visibility_level = "private"
}

resource "gitlab_project" "team_agent" {
  for_each = local.gitlab_teams

  namespace_id           = gitlab_group.team[each.key].id
  name                   = "k8s-agent"
  path                   = "k8s-agent"
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
