# MinIO to Garage S3 Migration Guide

## Overview

This guide covers the migration from MinIO to Garage S3. MinIO is being replaced due to deprecation concerns and Garage's better fit for our use case.

## Buckets to Migrate

1. **longhorn** - Longhorn backup storage
2. **postgres-backups** - PostgreSQL WAL-G backups
3. **user-avatars** - Website user avatar storage (new)

## Pre-Migration Checklist

- [ ] Garage S3 is deployed and running
- [ ] Garage pod is accessible via kubectl
- [ ] Vault is accessible for secret updates

## Migration Steps

### Step 1: Deploy Garage S3

Ensure Garage S3 is deployed via ArgoCD:

```bash
kubectl get pods -n garage-s3
```

You should see `garage-0` pod running.

### Step 2: Run Migration Script

Execute the migration script to create buckets and keys:

```bash
./scripts/migrate-minio-to-garage.sh
```

This script will:

- Create access keys for each service
- Create the required buckets
- Set appropriate permissions
- Display the credentials (save these!)

### Step 3: Update Vault Secrets

Copy the access keys and secret keys from the script output and update Vault:

```bash
# For postgres backups
vault kv put kvv2/garage-s3/postgres-backup-key \
  AWS_ACCESS_KEY_ID="<access_key_from_script>" \
  AWS_SECRET_ACCESS_KEY="<secret_key_from_script>"

# For longhorn backups
vault kv put kvv2/garage-s3/longhorn-backup-key \
  AWS_ACCESS_KEY_ID="<access_key_from_script>" \
  AWS_SECRET_ACCESS_KEY="<secret_key_from_script>"

# For user avatars
vault kv put kvv2/garage-s3/user-avatars-key \
  AWS_ACCESS_KEY_ID="<access_key_from_script>" \
  AWS_SECRET_ACCESS_KEY="<secret_key_from_script>"
```

Or update via Terraform by setting these variables in `secrets_variables.tfvars`:

```hcl
garage_postgres_backup_access_key_var = "<access_key>"
garage_postgres_backup_secret_key_var = "<secret_key>"
garage_longhorn_backup_access_key_var = "<access_key>"
garage_longhorn_backup_secret_key_var = "<secret_key>"
garage_user_avatars_access_key_var    = "<access_key>"
garage_user_avatars_secret_key_var    = "<secret_key>"
```

Then apply:

```bash
cd terraform
terraform apply
```

### Step 4: Update Service Configurations

The following configurations have been updated to use Garage S3:

#### PostgreSQL Operator

- Endpoint changed from `minio-s3.minio-s3.svc.cluster.local:9000` to `garage.garage-s3.svc.cluster.local:3900`
- Secret reference: `postgres-s3-credentials` (pulls from Vault)

#### Longhorn (if configured)

- Update Longhorn backup target to use Garage S3 endpoint
- Endpoint: `s3://longhorn@garage-s3/`
- Region: `garage`
- Endpoint URL: `http://garage.garage-s3.svc.cluster.local:3900`

### Step 5: Test Connectivity

Test that services can connect to Garage S3:

#### Test PostgreSQL Backup

```bash
# Check postgres operator logs
kubectl logs -n postgres -l application=spilo --tail=50 | grep -i s3

# Trigger a manual backup (if needed)
kubectl exec -it postgres-cluster-0 -n postgres -- /usr/bin/envdir "/run/etc/wal-e.d/env" /usr/local/bin/wal-g backup-push /home/postgres/pgdata/pgroot/data
```

#### Test Garage S3 Access

```bash
# Install s3cmd or aws cli in a test pod
kubectl run -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  s3 --endpoint-url=http://garage.garage-s3.svc.cluster.local:3900 \
  ls s3://postgres-backups/
```

### Step 6: Verify and Monitor

Monitor the services for 24-48 hours:

```bash
# Check postgres backups are working
kubectl logs -n postgres -l application=spilo -f | grep backup

# Check garage logs
kubectl logs -n garage-s3 garage-0 -f
```

### Step 7: Cleanup MinIO (After Verification)

Once you've verified everything works with Garage S3:

1. Delete the MinIO ArgoCD application:

```bash
kubectl delete application minio-s3 -n argocd
```

2. Remove MinIO configuration:

```bash
rm -rf k8s/config/minio-s3
rm k8s/apps/minio-s3.yaml
```

3. Clean up MinIO PVC (optional - only if you don't need the data):

```bash
kubectl delete pvc minio-nas-pvc -n minio-s3
kubectl delete namespace minio-s3
```

## Endpoints Reference

### MinIO (Old)

- API: `http://minio-s3.minio-s3.svc.cluster.local:9000`
- Console: `http://minio-s3.minio-s3.svc.cluster.local:9001`
- External: `https://s3.arffornia.com`

### Garage S3 (New)

- API: `http://garage.garage-s3.svc.cluster.local:3900`
- Web: `http://garage.garage-s3.svc.cluster.local:3902`
- External API: `https://s3.arffornia.com`
- External Web: `https://avatars-s3.arffornia.com`

## Troubleshooting

### Bucket not found

```bash
# List all buckets
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket list

# Create missing bucket
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket create <bucket-name>
```

### Permission denied

```bash
# Check key permissions
kubectl exec -it garage-0 -n garage-s3 -- /garage key info <key-name>

# Grant permissions
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket allow <bucket> --read --write --owner --key <key-name>
```

### Connection refused

Check that Garage service is running:

```bash
kubectl get svc -n garage-s3
kubectl get pods -n garage-s3
```

## Rollback Plan

If issues occur, you can rollback to MinIO:

1. Revert postgres-cluster.yaml endpoints back to MinIO
2. Redeploy MinIO via ArgoCD
3. Restore MinIO credentials in services

## Notes

- Garage S3 uses port 3900 for S3 API (vs MinIO's 9000)
- Garage S3 uses port 3902 for web interface (vs MinIO's 9001)
- Garage doesn't support automatic bucket creation via Helm values
- All bucket management must be done via CLI or API
- Data is NOT migrated - this is a fresh start (as requested)
