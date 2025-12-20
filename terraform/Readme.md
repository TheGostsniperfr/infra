# Working with Terraform

Terraform is used to:

- Provision Vault
  - Auth Methods
  - Policies
  - Secrets Engines
  - Secrets

## How to use Terraform

```sh
terraform init
```

### Register Real Secrets

You also need to create the `secrets_variables.tfvars` file. (You should take a loot at `secrets_variables.tfvars.example` 👀)

### Setup Vault connection

To provision the vault using terraform you need to setup the vault connection using either:

- `VAULT_TOKEN` environment variable (containing a valid token)
- `~/.vault-token` file (containing a valid token)

### Plan your changes

```sh
terraform plan -var-file="secrets_variables.tfvars"
```

### Apply your changes

```sh
terraform apply -var-file="secrets_variables.tfvars"
```

Then type `yes` to confirm the operation.
