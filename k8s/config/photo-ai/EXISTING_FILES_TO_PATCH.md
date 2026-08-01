# Manual patches required for existing infra files

These three files need manual edits before pushing to ArgoCD.

---

## 1. k8s/config/postgres/postgres-cluster.yaml

Add `photoai` and `immich` to both `databases` and `users`, and add pg_hba entries:

```yaml
# under spec.databases — add:
    photoai: photoai
    immich: immich

# under spec.users — add:
    photoai: []
    immich: []

# under spec.patroni.pg_hba — add before the hostssl catch-all:
      - hostnossl photoai photoai 192.168.1.0/24 md5
      - hostnossl immich immich 0.0.0.0/0 md5
```

After applying, the zalando operator creates k8s secrets:
- `photoai.postgres-cluster.credentials.postgresql.acid.zalan.do` in namespace `postgres`
- `immich.postgres-cluster.credentials.postgresql.acid.zalan.do` in namespace `postgres`

Copy those credentials into Vault:
```bash
# Get the auto-generated password
kubectl get secret photoai.postgres-cluster.credentials.postgresql.acid.zalan.do \
  -n postgres -o jsonpath='{.data.password}' | base64 -d

# Then store in Vault:
vault kv put kvv2/postgres/photoai username=photoai password=<above>
vault kv put kvv2/postgres/immich  username=immich  password=<above>
```

---

## 2. k8s/config/postgres/kustomization.yaml

The `postgres-lb.yaml` file is in `k8s/config/photo-ai/` and creates a Service in the
`postgres` namespace. If kustomize cross-namespace resources cause issues, move it:

```bash
cp k8s/config/photo-ai/postgres-lb.yaml k8s/config/postgres/postgres-lb.yaml
# then add to k8s/config/postgres/kustomization.yaml:
#   resources:
#     - postgres-lb.yaml
# and remove from k8s/config/photo-ai/kustomization.yaml
```

---

## 3. k8s/config/nextcloud/nextcloud-values.yaml

Add Recognize to NEXTCLOUD_INSTALL_APPS and a lifecycle hook:

```yaml
# Change:
  - name: NEXTCLOUD_INSTALL_APPS
    value: "files_external"
# To:
  - name: NEXTCLOUD_INSTALL_APPS
    value: "files_external,recognize"

# Add at root level (after phpClientHttpsFix):
lifecycle:
  postStartCommand:
    - /bin/sh
    - -c
    - sleep 60 && php /var/www/html/occ app:enable recognize 2>/dev/null || true
```

---

## 4. k8s/apps/kustomization.yaml

Add to the `resources` list under `# Applications`:

```yaml
  - photo-ai.yaml
  - immich.yaml
```

---

## 5. Vault secrets to create

```bash
# Discord bot token + guild ID
vault kv put kvv2/photo-ai/discord token=<discord-bot-token> guild_id=577223034642104328

# Shared auth token (generate a random one)
vault kv put kvv2/photo-ai/runner auth_token=$(openssl rand -hex 32)

# Immich session secret
vault kv put kvv2/immich/secret-key value=$(openssl rand -hex 32)
```

## 6. Vault policies to create

Each new app needs a Vault role. Use the same pattern as existing apps (check vault config).
Roles needed: `photo-ai-role`, `immich-role`.

## 7. Discord bot — set Guild ID

In `k8s/config/photo-ai/discord-bot.yaml`, replace:
```
value: "REPLACE_WITH_YOUR_GUILD_ID"
```
with your Discord server ID (right-click server → Copy Server ID).
