# Longhorn Policy
path "${mount_path}/data/minio-s3/credentials" {
  capabilities = ["read"]
}

path "${mount_path}/data/garage-s3/longhorn-backup-key" {
  capabilities = ["read"]
}

path "${mount_path}/data/longhorn/envoy-auth" {
  capabilities = ["read"]
}
