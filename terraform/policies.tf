# resource "vault_policy" "fixme_policy" {
#   name = "fixme-policy"
#   policy = templatefile("${path.module}/policies/fixme.hcl", {
#     mount_path = vault_mount.kvv2.path
#   })
# }


# -----------------------------------------------------------------------------
# Arffornia Policies (Grouped)
# -----------------------------------------------------------------------------

resource "vault_policy" "arffornia_proxy_policy" {
  name = "arffornia-proxy-policy"
  policy = templatefile("${path.module}/policies/arffornia_proxy.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

resource "vault_policy" "arffornia_server_policy" {
  name = "arffornia-server-policy"
  policy = templatefile("${path.module}/policies/arffornia_server.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

resource "vault_policy" "arffornia_website_policy" {
  name = "arffornia-website-policy"
  policy = templatefile("${path.module}/policies/arffornia_website.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Adminer Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "adminer_policy" {
  name = "adminer-policy"
  policy = templatefile("${path.module}/policies/adminer.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# CSI Driver SMB Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "csi_driver_smb_policy" {
  name = "csi-driver-smb-policy"
  policy = templatefile("${path.module}/policies/csi_driver_smb.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Keycloak Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "keycloak_policy" {
  name = "keycloak-policy"
  policy = templatefile("${path.module}/policies/keycloak.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Longhorn Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "longhorn_policy" {
  name = "longhorn-policy"
  policy = templatefile("${path.module}/policies/longhorn.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Minio S3 Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "minio_s3_policy" {
  name = "minio-s3-policy"
  policy = templatefile("${path.module}/policies/minio_s3.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Monitoring Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "monitoring_policy" {
  name = "monitoring-policy"
  policy = templatefile("${path.module}/policies/monitoring.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# N8n Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "n8n_policy" {
  name = "n8n-policy"
  policy = templatefile("${path.module}/policies/n8n.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Nextcloud Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "nextcloud_policy" {
  name = "nextcloud-policy"
  policy = templatefile("${path.module}/policies/nextcloud.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Plex Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "plex_policy" {
  name = "plex-policy"
  policy = templatefile("${path.module}/policies/plex.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Postgres Operator Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "postgres_policy" {
  name = "postgres-policy"
  policy = templatefile("${path.module}/policies/postgres.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Vaultwarden Policy
# -----------------------------------------------------------------------------

resource "vault_policy" "vaultwarden_policy" {
  name = "vaultwarden-policy"
  policy = templatefile("${path.module}/policies/vaultwarden.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

# -----------------------------------------------------------------------------
# Operator Policies
# -----------------------------------------------------------------------------

resource "vault_policy" "vault_secrets_operator_policy" {
  name = "vault-secrets-operator-policy"
  policy = templatefile("${path.module}/policies/vault_secrets_operator.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}
