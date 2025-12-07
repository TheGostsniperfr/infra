resource "vault_policy" "fixme_policy" {
  name = "fixme-policy"
  policy = templatefile("${path.module}/policies/fixme.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}
