# Arffornia world backups: retention and restore

Scope: the Arcane server (`arffornia-server-arcane`). Nexus has no backup today.

## How backups work

- The `mc-backup` sidecar ([itzg/docker-mc-backup](https://github.com/itzg/docker-mc-backup)) runs in the server pod.
  It waits `initialDelay` (10 min) after the pod starts, then makes a backup every `backupInterval` (24 h)
  while players are online.
- The server sleeps from 03:00 to 07:00 (offhours-guard), so in practice there is one backup per day
  the cluster is up, about 10 minutes after the 07:00 wake-up.
- Each backup is `world-YYYYMMDD-HHMMSS.tar.gz` (the `world` folder only), taken with `save-off` / `save-all flush`
  over RCON, and written to the NAS: `//192.168.1.49/raid5_proxmox/arffornia/backups/arcane`
  (PVC `arffornia-backup-arcane-pvc`, mounted at `/backups`).
- After each backup, `post-backup.sh` (ConfigMap `arffornia-backup-scripts`):
  1. reads the new archive back and checks that it contains `world/level.dat`.
     A broken archive is renamed `*.tar.gz.broken`: it is kept for inspection and does not count in the retention;
  2. copies the first good archive of each month to `/backups/monthly/`.

## Retention

Retention is by **count**, never by age. Starting the cluster after months off deletes nothing.

| Setting (in `k8s/config/arffornia/server/overlays/arcane/patch-values.yaml`) | Default | Meaning |
|---|---|---|
| `mcbackup.extraEnv.PRUNE_BACKUPS_COUNT` | `14` | Daily archives kept in `/backups` (the newest N files) |
| `mcbackup.extraEnv.MONTHLY_KEEP` | `0` | Monthly copies kept in `/backups/monthly`. `0` = keep forever, `12` = one year |
| `mcbackup.extraEnv.VERIFY_BACKUP` | `true` | Read each archive back before trusting it (one extra read of the archive on the NAS) |
| `mcbackup.pruneBackupsDays` | `0` | Age-based pruning. Keep it at `0`: a positive value brings back "a long shutdown deletes everything" |

Change a value, open a PR, merge: Argo CD restarts the pod with the new setting.

Sizes: each archive is roughly the size of the compressed world. Check with
`ls -lh` on the NAS share, or the command in "List the backups" below.

## List the backups

From a machine with `kubectl` access, while the server pod runs:

```sh
NS=arffornia-server-arcane
POD=$(kubectl -n $NS get pod -l app=arffornia-server-arcane-minecraft -o name | head -n1)
kubectl -n $NS exec $POD -c arffornia-server-arcane-minecraft-mc-backup -- ls -lht /backups /backups/monthly
kubectl -n $NS logs $POD -c arffornia-server-arcane-minecraft-mc-backup --tail=100   # last backup, verify, prune
```

Or straight on the NAS: `raid5_proxmox/arffornia/backups/arcane/`.

## Restore a world

Restoring replaces the live world. Players lose everything since that backup. Tell them first.

1. **Pick the archive.** Prefer the newest daily one that is not `.broken`. For older states use `monthly/`.
2. **Stop Argo CD from undoing your changes.** In the Argo CD UI, turn off auto-sync on `apps` (the app of apps)
   and then on `arffornia-server-arcane`. If you only turn it off on the second one, `apps` turns it back on.
3. **Stop the server.**
   ```sh
   NS=arffornia-server-arcane
   kubectl -n $NS scale deploy/arffornia-server-arcane-minecraft --replicas=0
   kubectl -n $NS wait --for=delete pod -l app=arffornia-server-arcane-minecraft --timeout=5m
   ```
   Do it outside 03:00 and 07:00, because offhours-guard scales the server at those times.
4. **Run a restore pod** that mounts the world volume and the backups:
   ```sh
   kubectl -n $NS apply -f - <<'EOF'
   apiVersion: v1
   kind: Pod
   metadata:
     name: world-restore
   spec:
     restartPolicy: Never
     securityContext: {runAsUser: 1000, runAsGroup: 3000, fsGroup: 2000}
     containers:
       - name: restore
         image: alpine:3.22
         command: ["sleep", "7200"]
         volumeMounts:
           - {name: data, mountPath: /data}
           - {name: backups, mountPath: /backups, readOnly: true}
     volumes:
       - name: data
         persistentVolumeClaim: {claimName: arffornia-server-arcane-minecraft-datadir}
       - name: backups
         persistentVolumeClaim: {claimName: arffornia-backup-arcane-pvc}
   EOF
   kubectl -n $NS wait --for=condition=Ready pod/world-restore --timeout=5m
   ```
5. **Swap the world**, keeping the current one aside:
   ```sh
   ARCHIVE=/backups/world-20261031-071012.tar.gz   # the one you picked
   kubectl -n $NS exec world-restore -- sh -c "
     set -e
     tar -tzf $ARCHIVE | grep -q 'level.dat$'
     mv /data/world /data/world.before-restore-\$(date +%Y%m%d-%H%M%S)
     tar -xzf $ARCHIVE -C /data
     ls -la /data/world | head"
   ```
6. **Clean up and start again.**
   ```sh
   kubectl -n $NS delete pod world-restore
   kubectl -n $NS scale deploy/arffornia-server-arcane-minecraft --replicas=1
   ```
   Turn auto-sync back on: first `arffornia-server-arcane`, then `apps`.
7. **Check.** The server reaches `Done (`, you can join, the spawn and a known base look right.
   When you are sure, delete `/data/world.before-restore-*` (it uses as much space as the world).

The world volume is Longhorn (30 GiB). If it is too small to hold both worlds during step 5, move the old world
to the NAS first, or delete it after the archive check.

## Test the restore

A backup you never restored is a hope, not a backup. Once per quarter, when you start the cluster:

- extract the newest archive into a scratch pod (the restore pod above, without the `mv`, into `/tmp`), and
- start a throwaway server on it, or at least check that `level.dat` and the `region/` folders are there.

The planned preview environments (ADR-0007) can boot a copy of the latest backup and make this automatic.

## Not covered yet

- **Off-site copy.** Everything is on the same NAS, on the same site. A NAS failure loses the world and every backup.
- **Database.** LuckPerms, progression and accounts are in Postgres, backed up by WAL-G to in-cluster Garage S3.
  A world restore does not roll the database back.
- **Deduplicated history.** Moving to restic (`--keep-last`, `--keep-daily`, `--keep-monthly`) would store years
  of history for little space. See the infra issue on off-site backups.
