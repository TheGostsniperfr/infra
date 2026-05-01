# Migration Ingress → Gateway API

## Services migrés vers Gateway API (secure-route)

### Avec authentification OIDC Keycloak

1. **Adminer** - `adminer.arffornia.com`
   - Auth: OIDC via Envoy Gateway
   - Secret Vault: `kvv2/adminer/envoy-auth`

2. **Longhorn** - `longhorn.arffornia.com`
   - Auth: OIDC via Envoy Gateway
   - Secret Vault: `kvv2/longhorn/envoy-auth`

### Sans authentification (auth interne ou public)

3. **N8n** - `n8n.arffornia.com`
4. **Nextcloud** - `nextcloud.arffornia.com`
5. **Vaultwarden** - `vaultwarden.arffornia.com`
6. **Coder** - `coder.arffornia.com`
7. **Vault** - `vault.arffornia.com`
8. **Ollama** - `ollama.arffornia.com`
9. **Arffornia Bluemap** - `map.arffornia.com`
10. **ArgoCD** - `argocd.arffornia.com` (déjà migré)
11. **Keycloak** - `auth.arffornia.com`, `admin-auth.arffornia.com` (déjà migré)
12. **Garage S3** - `s3.arffornia.com`, `avatars-s3.arffornia.com` (déjà migré)

## Fichiers supprimés

- `k8s/config/adminer/ingress.yaml` → remplacé par `values-secure-route.yaml`
- `k8s/config/longhorn/longhorn-ingress.yaml` → remplacé par `values-secure-route.yaml`
- `k8s/config/ollama/ingress.yaml` → remplacé par `values-secure-route.yaml`
- `k8s/config/arffornia/bluemap-web/ingress.yaml` → remplacé par `values-secure-route.yaml`
- Ingress désactivé dans `k8s/config/n8n/values.yaml`

## Configuration Terraform

### Nouveau client OIDC

- **Client ID**: `arffornia-openid`
- **Realm**: `arffornia`
- **Usage**: Authentification Envoy Gateway pour tous les services protégés

### Nouveaux secrets Vault

1. `kvv2/adminer/envoy-auth` - client-secret OIDC pour Adminer
2. `kvv2/longhorn/envoy-auth` - client-secret OIDC pour Longhorn

### Variables Terraform à définir

```bash
adminer_envoy_auth_client_secret_var = "<secret from Keycloak>"
longhorn_envoy_auth_client_secret_var = "<secret from Keycloak>"
```

## Chart secure-route

### Configuration globale mise à jour

```yaml
global:
  gatewayName: "shared-gateway"
  gatewayNamespace: "gateway-infra"
  baseDomain: "arffornia.com"
  keycloakRealm: "arffornia"
  authClientId: "arffornia-openid"
```

### Structure d'un values-secure-route.yaml

```yaml
routes:
  <service-name>:
    hostnames:
      - "<hostname>.arffornia.com"
    rules:
      - backendRefs:
          - name: <service-name>
            port: <port>
    auth:
      enabled: true/false
      vault:
        path: "kvv2/<service>/envoy-auth"
        role: "<service>-role"
    ipFilter:
      enabled: false
```

## Étapes de déploiement

1. **Terraform** : Appliquer les changements Terraform pour créer le client OIDC et les secrets
2. **Récupérer le client secret** : Depuis Keycloak, copier le secret du client `arffornia-openid`
3. **Configurer Vault** : Ajouter les secrets dans Vault pour adminer et longhorn
4. **Déployer** : Appliquer les changements Kubernetes via ArgoCD

## Notes

- Tous les services utilisent maintenant la Gateway API via Envoy Gateway
- Pas de filtrage IP configuré (accès depuis n'importe quelle IP)
- Les certificats TLS sont toujours gérés par cert-manager
- L'authentification OIDC est gérée au niveau de la Gateway (Envoy)
