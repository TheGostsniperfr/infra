# Monitoring (Grafana) Policy
path "${mount_path}/data/grafana/admin" {
  capabilities = ["read"]
}

path "${mount_path}/data/monitoring/discord" {
  capabilities = ["read"]
}
