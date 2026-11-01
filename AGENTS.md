# Agent notes for this repository

- Cluster changes go through git and Argo CD. Use `kubectl` by hand only for reads, deleting orphans, or a one-off patch git cannot express.
- Vault secrets, policies and roles change only through `terraform/`, never with `vault kv put` or `vault policy write`.
- Never commit secrets. The Terraform state backend credentials and the tfvars values are in sops on the workstation, see `terraform/Readme.md`. There is no `secrets_variables.tfvars` file to find or recreate: decrypt it on the fly with `sops decrypt` as documented there.
- Never print the content of `~/.config/arffornia/tf-backend.env` or of the decrypted tfvars.
- Do not add a classical (X25519) recipient to `arffornia-tfvars.json`. It is post-quantum only.
- Open a branch and a PR with a conventional commit. Never push to `main` and never force-push. Include "Applied on <date>" in the body of PRs that were applied with Terraform.
