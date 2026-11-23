# Platform secrets of the app teams, read by their VaultSecrets: registry and deploy repo tokens,
# cosign public keys. The name dates from the GitLab agents, which are gone
path "${mount_path}/data/gitlab-agents/*" {
  capabilities = ["read"]
}
