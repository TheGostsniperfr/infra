# AGENTS.md: infra

Brian's homelab: a Kubernetes cluster run by Argo CD (GitOps), plus Terraform for Vault,
Keycloak and Cloudflare. Read this before changing anything here.

## Layout
| Path | What |
|---|---|
| `k8s/apps/` | Argo CD `Application`s, one per app (app of apps: `k8s/apps/kustomization.yaml`) |
| `k8s/config/<app>/` | What each Application deploys: kustomize, Helm values, `VaultSecret`s |
| `charts/` | Local Helm charts (`secure-route`, the Arffornia charts) |
| `terraform/` | Vault (auth, policies, roles, secrets), Keycloak, Cloudflare DNS. See `terraform/Readme.md` |

## How changes reach the cluster
- Argo CD syncs `HEAD` of `main` with prune and selfHeal, so a merged change is live. Render the
  kustomization before you push: `kustomize build --enable-helm <dir>`.
- Terraform is never applied by CI. `plan` and `apply` run on Brian's machine, because the
  state backend credentials only live there (see `terraform/Readme.md`).
- Agents have no cluster or backend access. Anything that needs `kubectl`, `vault` or
  `terraform apply` goes into a prompt or runbook for Brian's local session.

## Rules
- **Vault secrets, policies and roles are always managed through Terraform (`terraform/`), never
  by hand.** That covers `vault kv put`, `vault policy write` and `vault write auth/...` alike. To
  change a secret value, edit the sops-encrypted tfvars on Brian's machine (see
  `terraform/Readme.md`) and run `terraform apply`; to change access, edit
  `terraform/policies/*.hcl` or `roles.tf`. A change made by hand is drift: the next `apply` reverts it, or the state no longer describes Vault.
- **Never commit secrets.** The state backend credentials and the tfvars values are in sops on
  Brian's workstation, see `terraform/Readme.md`. There is no `secrets_variables.tfvars` file to
  find or recreate: it is decrypted on the fly with `sops decrypt` as documented there.
- Never print the content of `~/.config/arffornia/tf-backend.env` or of the decrypted tfvars.
- Do not add a classical (X25519) recipient to `arffornia-tfvars.json`. It is post-quantum only.
- **Kubernetes secrets** come only from `VaultSecret` CRs (Vault Secrets Operator) or `${CFG_*}`
  placeholders. Never commit a literal secret or a base64 `Secret` manifest.
- **Postgres `pg_hba`** (`k8s/config/postgres/postgres-cluster.yaml`): any `patroni.pg_hba`
  override replaces the operator's defaults entirely, so it must always keep these lines:
  ```yaml
  - local all all trust
  - host all all 127.0.0.1/32 md5
  - local replication standby trust
  - hostssl replication standby all md5
  ```
  Without the `local` lines the operator and the WAL-G backups cannot connect. Without the
  `replication` lines the replicas stop streaming. Both happened once (fixed in e681d24).
- **Pin everything**: image tags (never `:latest`), chart versions, remote bases by tag.
- **Free only**: self-hosted or free tiers. The only exceptions are a DNS name or a few euros
  over a long period.
- English, Conventional Commits, one concern per PR. Never push to `main`. PRs that were applied
  with Terraform say "Applied on <date>" in their body. Open infra PRs may lag behind `main`: merge
  `main` into them, never force-push.

## Storage and backups (state after the 2026-10-31 recovery)
- S3 is Garage only (`garage-s3` namespace, `https://s3.arffornia.com`). It holds the buckets
  `tf-state`, `longhorn`, `postgres-backups` and `user-avatars`. MinIO and AWS are gone.
- Garage runs a single node with replication factor 1. Longhorn snapshots its volumes every
  night (`k8s/config/longhorn/recurring-job-garage.yaml`, group `garage`).
