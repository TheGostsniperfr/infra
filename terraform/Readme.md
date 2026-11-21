# Working with Terraform

Terraform is used to:

- Provision Vault
  - Auth Methods
  - Policies
  - Secrets Engines
  - Secrets
- Configure Keycloak (realm, clients, scopes, users)
- Manage Cloudflare DNS records

> **Rule: Vault secrets, policies and roles are always managed here, never by hand.**
> Do not run `vault kv put`, `vault policy write` or `vault write auth/...` directly. Change
> the sops-encrypted tfvars (see "Register Real Secrets"), `policies/*.hcl` or `roles.tf`, then
> `terraform apply`. Changes made by hand drift from the state and get reverted by the next apply.

## State backend: Garage S3

Since 2026-10-31 the state lives in the self-hosted Garage cluster, not AWS (the AWS account is
closed). See the `backend "s3"` block in `providers.tf`:

- endpoint `https://s3.arffornia.com`, bucket `tf-state`, key `infra/terraform.tfstate`;
- path-style addressing, region `garage`, AWS-only checks skipped;
- locking with `use_lockfile` (a lock object in the bucket), with no DynamoDB.

Credentials are the Garage key `tf-state-key`. They are not in git: they are managed by sops-nix
on Brian's workstation and exposed at `~/.config/arffornia/tf-backend.env` (a symlink to
`/run/secrets/arffornia_tf_backend`), so source that file before running Terraform:

```sh
set -a; . ~/.config/arffornia/tf-backend.env; set +a   # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
terraform init
```

The state contains every secret in clear text, so the bucket is only reachable with that key.
Agents and CI have no backend credentials: `plan` and `apply` run on Brian's machine.

## How to use Terraform

```sh
terraform init   # after sourcing the backend credentials, see above
```

### Register Real Secrets

The real values are not stored in this repository. They live encrypted in `~/.dotfiles/secrets/arffornia-tfvars.json`, for a post-quantum age key only (ML-KEM-768 + X25519, kept in `~/.config/sops/age/keys.txt`). There is no plaintext `secrets_variables.tfvars` on disk: it is decrypted on the fly (see below).

To add or change a variable, edit it with `sops --input-type json ~/.dotfiles/secrets/arffornia-tfvars.json`. The file is a sops binary document, so the editor shows the whole tfvars content in its `data` field. Keep `secrets_variables.tfvars.example` in sync. Never add a classical age recipient to this file: it would defeat the post-quantum protection.

### Setup Vault connection

To provision the vault using terraform you need to setup the vault connection using either:

- `VAULT_TOKEN` environment variable (containing a valid token)
- `~/.vault-token` file (containing a valid token)

### Setup Cloudflare connection
To provision the cloudflare resources using terraform you need to use the `CLOUDFLARE_API_TOKEN` environment variable with edit zone scope.

```sh
export CLOUDFLARE_API_TOKEN="token"
```

### Setup the Microsoft Entra connection

`microsoft_apps.tf` manages the website's Microsoft app registrations with the `azuread`
provider, authenticated by the Azure CLI. Log in with the account that owns the apps:

```sh
nix shell nixpkgs#azure-cli
az login --allow-no-subscriptions
az ad app list --query '[].{name:displayName,objectId:id,clientId:appId}' -o table
```

To import the prod app, pass its **object id** (not the client id) as
`-var azure_prod_app_object_id_var=<object id>` or put it in the sops tfvars. Without it, the
prod app stays outside Terraform. Imported with `ignore_changes = all`, so the import plan
changes nothing.

For now staging and pr1-pr3 sign in with the prod app, already approved for Minecraft
(`staging_uses_prod_microsoft_app_var`, default `true`): Terraform adds their redirect URIs to
the prod app, keeps every other URI it already has, and writes the prod client id and secret to
the staging and previews Vault paths. This needs the prod object id. Once "Arffornia Test" is
approved, pass `-var staging_uses_prod_microsoft_app_var=false` (or set it in the tfvars) and
apply: the test URIs leave the prod app and the test app's id and secret go to Vault.

Terraform cannot give Minecraft access to a new client id: until Microsoft approves it through
https://aka.ms/mce-reviewappid, `login_with_xbox` answers 403 and the website login fails after
the Microsoft consent page. The "Arffornia Test" app needs this review once.

### Plan your changes

```sh
terraform plan -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/arffornia-tfvars.json)
```

### Apply your changes

```sh
terraform apply -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/arffornia-tfvars.json)
```

Then type `yes` to confirm the operation.
