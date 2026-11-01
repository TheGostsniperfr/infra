# Working with Terraform

Terraform is used to:

- Provision Vault
  - Auth Methods
  - Policies
  - Secrets Engines
  - Secrets

## How to use Terraform

### Backend credentials

The state lives in Garage S3 (bucket `tf-state`) and holds every secret in clear. Its credentials are managed by sops-nix on the workstation and exposed at `~/.config/arffornia/tf-backend.env` (symlink to `/run/secrets/arffornia_tf_backend`).

```sh
set -a; . ~/.config/arffornia/tf-backend.env; set +a
terraform init
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

### Plan your changes

```sh
terraform plan -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/arffornia-tfvars.json)
```

### Apply your changes

```sh
terraform apply -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/arffornia-tfvars.json)
```

Then type `yes` to confirm the operation.
