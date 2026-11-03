# GitLab Policy
path "${mount_path}/data/postgres/gitlab" {
  capabilities = ["read"]
}
path "${mount_path}/data/gitlab/*" {
  capabilities = ["read"]
}
