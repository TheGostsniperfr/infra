# Longhorn Policy
path "${mount_path}/data/minio-s3/credentials" {
  capabilities = ["read"]
}

path "${mount_path}/data/longhorn/envoy-auth" {
  capabilities = ["read"]
}
