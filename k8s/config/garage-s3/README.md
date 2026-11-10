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

## Metadata corruption recovery

On 2026-11-10, after a power cut, the LMDB metadata DB was corrupted (`MDB_PAGE_NOTFOUND`, then a
panic in `table/merkle.rs`). Garage was down, so PostgreSQL could not archive WAL and never left
crash recovery, and Terraform could not read its state. Since then `metadata_fsync = true` and
snapshots every 6 h (`/mnt/meta/snapshots`) are enabled. If it happens again:

1. Snapshot the `meta-garage-0` Longhorn volume as-is, clone it into a PVC
   (`dataSource: {kind: PersistentVolumeClaim, name: meta-garage-0}`) and work on the clone only.
2. Easiest: copy the newest directory of `/mnt/meta/snapshots/` over `db.lmdb`.
3. Otherwise rebuild the DB with `lmdb-tools` (Alpine): `mdb_dump -s <tree>` each tree listed by
   `mdb_dump -l`, `mdb_load -s <tree>` into a new environment. `mdb_dump` exits 0 even on a read
   error, so compare `mdb_stat -s <tree>` entry counts. Only derived trees may be emptied:
   `*_resync_queue`, `*:merkle_todo`, `*:merkle_tree`, `*:gc_todo_v2`, `*:insert_queue`.
   A `merkle_todo` value must be 32 bytes or empty, anything else makes Garage panic.
4. Check the result with `garage convert-db -a lmdb -i <new> -b sqlite -o /tmp/check.sqlite`.
5. While `garage-0` is in CrashLoopBackOff, from a pod on the same node mounting `meta-garage-0`:
   move `db.lmdb` aside, put the new `data.mdb` in a fresh `db.lmdb/` (owner 1000), delete the pod.
6. `garage repair --yes blocks` to rebuild the resync queue.

## Migration

See [MINIO_TO_GARAGE_MIGRATION.md](../../docs/MINIO_TO_GARAGE_MIGRATION.md) for migration guide from MinIO.
