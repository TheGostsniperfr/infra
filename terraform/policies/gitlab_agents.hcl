# GitLab Agents Policy: one token per team, read by the VaultSecret in each agent namespace
path "${mount_path}/data/gitlab-agents/*" {
  capabilities = ["read"]
}
