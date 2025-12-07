# kvc2 setup
# Doc: https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/kv_secret_v2

resource "vault_mount" "kvv2" {
  path        = "my-kvv2"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}
