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
> `secrets_variables.tfvars`, `policies/*.hcl` or `roles.tf`, then `terraform apply`. Changes
> made by hand drift from the state and get reverted by the next apply.

## State backend: Garage S3

Since 2026-10-31 the state lives in the self-hosted Garage cluster, not AWS (the AWS account is
closed). See the `backend "s3"` block in `providers.tf`:

- endpoint `https://s3.arffornia.com`, bucket `tf-state`, key `infra/terraform.tfstate`;
- path-style addressing, region `garage`, AWS-only checks skipped;
- locking with `use_lockfile` (a lock object in the bucket), with no DynamoDB.

Credentials are the Garage key `tf-state-key`. They are not in git: on Brian's machine they are
in `~/.config/arffornia/tf-backend.env` (to be moved into sops-nix), so source that file before
running Terraform:

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

You also need to create the `secrets_variables.tfvars` file. (You should take a loot at `secrets_variables.tfvars.example` 👀)

### Setup Vault connection

To provision the vault using terraform you need to setup the vault connection using either:

- `VAULT_TOKEN` environment variable (containing a valid token)
- `~/.vault-token` file (containing a valid token)

### Setup Cloudflare connection
To provision the cloudflare resources using terraform you need to use the `CLOUDFLARE_API_TOKEN` environment variable with edit zone scope.

```sh
export CLOUDFLARE_API_TOKEN="token"
```

### Plan your changes

```sh
terraform plan -var-file="secrets_variables.tfvars"
```

### Apply your changes

```sh
terraform apply -var-file="secrets_variables.tfvars"
```

Then type `yes` to confirm the operation.
