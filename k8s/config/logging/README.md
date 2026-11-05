# Logging: steps outside Git

Loki stores its chunks and index in the Garage bucket `loki`. The bucket, its key and the
Vault secret must exist before Argo CD syncs this app, in this order.

## 1. Garage bucket and key

```sh
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket create loki
kubectl exec -it garage-0 -n garage-s3 -- /garage key create loki-key
kubectl exec -it garage-0 -n garage-s3 -- /garage bucket allow loki --read --write --owner --key loki-key
kubectl exec -it garage-0 -n garage-s3 -- /garage key info loki-key --show-secret
```

## 2. Vault secret through Terraform

Put the key ID (`GK...`) and the secret key in the sops tfvars, then apply
(see `terraform/Readme.md`):

```sh
sops --input-type json ~/.dotfiles/secrets/arffornia-tfvars.json
#   loki_s3_access_key_var = "GK..."
#   loki_s3_secret_key_var = "..."
terraform plan  -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/arffornia-tfvars.json)
terraform apply -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/arffornia-tfvars.json)
```

This creates `kvv2/logging/loki-s3`, the `logging-policy` and the `logging-role` that the
`loki-s3` VaultSecret uses.

## 3. Check after the sync

```sh
kubectl -n logging get pods                              # loki-0 2/2, one alloy per node
kubectl -n logging logs loki-0 -c loki | grep -i error   # no S3 access errors
kubectl -n logging exec loki-0 -c loki -- wget -qO- localhost:3100/loki/api/v1/rules
```

In Grafana: Explore > Loki > `{namespace="arffornia-server-arcane"}`.
