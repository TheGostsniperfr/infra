# Postgres Operator (for S3 backups) Policy
path "${mount_path}/data/garage-s3/postgres-backup-key" {
  capabilities = ["read"]
}
