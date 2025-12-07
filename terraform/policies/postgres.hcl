# Postgres Operator (for S3 backups) Policy
path "${mount_path}/data/minio-s3/credentials" {
  capabilities = ["read"]
}
