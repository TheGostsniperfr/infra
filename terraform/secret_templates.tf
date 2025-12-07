# Reference manual vars: https://developer.hashicorp.com/terraform/language/block/variable#specification

variable "fixme_var" {
  description = "An example of a var"
  type        = string
  sensitive   = true # Specifies if terraform hides this value in CLI output
}

# Doc: https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2
resource "vault_kv_secret_v2" "fixme_secret" {
  mount               = vault_mount.kvv2.path
  name                = "fixme/path"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode({
    FIXME_KEY = var.fixme_var
  })
}
