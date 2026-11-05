# Garage S3 Configuration

## Buckets

Current buckets:

- `longhorn` - Longhorn backup storage
- `postgres-backups` - PostgreSQL WAL-G backups
- `user-avatars` - Website user avatar storage
- `loki` - Loki log chunks, index and ruler data (k8s/config/logging)
- `gitlab-*` - GitLab object storage: `gitlab-lfs`, `gitlab-artifacts`, `gitlab-uploads`,
  `gitlab-packages`, `gitlab-terraform-state`, `gitlab-ci-secure-files`, `gitlab-dependency-proxy`,
  `gitlab-registry`, `gitlab-backups`, `gitlab-tmp`

## Access Keys

Current keys:

- `longhorn-backup-key` - For Longhorn backups
- `postgres-backup-key` - For PostgreSQL backups
- `user-avatars-key` - For website avatars (public read)
- `loki-key` - For the `loki` bucket
- `gitlab-key` - For every `gitlab-*` bucket

## Management Commands

### Create an access key

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage key new --name <key-name>
```

### Create a bucket

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket create <bucket-name>
```

### Grant bucket permissions

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket allow <bucket-name> --read --write --owner --key <key-name>
```

### Allow public read access

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket allow <bucket-name> --key <key-name> --read
```

### View key information

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage key info <key-name>
```

### View bucket information

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket info <bucket-name>
```

### List all buckets

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket list
```

### List all keys

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage key list
```

## Endpoints

- **S3 API**: `http://garage.garage-s3.svc.cluster.local:3900`
- **Web Interface**: `http://garage.garage-s3.svc.cluster.local:3902`
- **External S3 API**: `https://s3.arffornia.com`
- **External Web**: `https://avatars-s3.arffornia.com`

## Migration

See [MINIO_TO_GARAGE_MIGRATION.md](../../docs/MINIO_TO_GARAGE_MIGRATION.md) for migration guide from MinIO.
