# Postgres Operator (for S3 backups) Policy
path "${mount_path}/data/minio-s3/credentials" {
  capabilities = ["read"]
}

path "${mount_path}/data/garage-s3/postgres-backup-key" {
  capabilities = ["read"]
}
