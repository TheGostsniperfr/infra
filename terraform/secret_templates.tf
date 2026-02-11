# Reference manual vars: https://developer.hashicorp.com/terraform/language/block/variable#specification

# variable "fixme_var" {
#   description = "An example of a var"
#   type        = string
#   sensitive   = true # Specifies if terraform hides this value in CLI output
# }

# Doc: https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2
# resource "vault_kv_secret_v2" "fixme_secret" {
#   mount               = vault_mount.kvv2.path
#   name                = "fixme/path"
#   cas                 = 1
#   delete_all_versions = true
#   data_json = jsonencode({
#     FIXME_KEY = var.fixme_var
#   })
# }


# -----------------------------------------------------------------------------
# Cloudflare Secrets
# -----------------------------------------------------------------------------

variable "cloudflare_api_token_secret_var" {
  description = "Cloudflare API token with permissions to manage DNS records."
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Arffornia K8s Cluster Secrets
# -----------------------------------------------------------------------------

# --- Arffornia Proxy ---
variable "arffornia_forwarding_secret_var" {
  description = "Velocity forwarding secret."
  type        = string
  sensitive   = true
}
variable "arffornia_nuvotifier_token_var" {
  description = "NuVotifier token."
  type        = string
  sensitive   = true
}
variable "arffornia_nuvotifier_private_key_var" {
  description = "NuVotifier private key."
  type        = string
  sensitive   = true
}
variable "arffornia_nuvotifier_public_key_var" {
  description = "NuVotifier public key."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "arffornia_proxy_secret" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/proxy"
  data_json = jsonencode({
    CFG_FORWARDING_SECRET      = var.arffornia_forwarding_secret_var
    CFG_NUVOTIFIER_TOKEN       = var.arffornia_nuvotifier_token_var
    CFG_NUVOTIFIER_PRIVATE_KEY = var.arffornia_nuvotifier_private_key_var
    CFG_NUVOTIFIER_PUBLIC_KEY  = var.arffornia_nuvotifier_public_key_var
  })
}

# --- Arffornia Service Accounts ---
variable "arffornia_svc_proxy_id_var" {
  description = "Service Account Client ID for the proxy."
  type        = string
  sensitive   = true
}
variable "arffornia_svc_proxy_password_var" {
  description = "Service Account Client Secret for the proxy."
  type        = string
  sensitive   = true
}
variable "arffornia_svc_id_var" {
  description = "Service Account Client ID for the Minecraft server."
  type        = string
  sensitive   = true
}
variable "arffornia_svc_password_var" {
  description = "Service Account Client Secret for the Minecraft server."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "arffornia_svc_proxy_secret" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/svc-proxy"
  data_json = jsonencode({
    SVC_ID       = var.arffornia_svc_proxy_id_var
    SVC_PASSWORD = var.arffornia_svc_proxy_password_var
  })
}

resource "vault_kv_secret_v2" "arffornia_svc_secret" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/svc"
  data_json = jsonencode({
    SVC_ID       = var.arffornia_svc_id_var
    SVC_PASSWORD = var.arffornia_svc_password_var
  })
}

# --- Arffornia Server ---
variable "arffornia_rcon_password_var" {
  description = "RCON password for Minecraft servers."
  type        = string
  sensitive   = true
}
variable "arffornia_discord_bot_channel_var" {
  description = "Discord bot channel ID."
  type        = string
  sensitive   = true
}
variable "arffornia_discord_bot_token_var" {
  description = "Discord bot token."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "arffornia_server_secret" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/server"
  data_json = jsonencode({
    CFG_RCON_PASSWORD = var.arffornia_rcon_password_var
  })
}

resource "vault_kv_secret_v2" "arffornia_discord_bot_secret" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/discord-bot"
  data_json = jsonencode({
    CFG_DISCORD_BOT_CHANNEL = var.arffornia_discord_bot_channel_var
    CFG_DISCORD_BOT_TOKEN   = var.arffornia_discord_bot_token_var
  })
}

# --- Arffornia Website ---
variable "website_app_key_var" {
  description = "Laravel application key for the website."
  type        = string
  sensitive   = true
}
variable "website_azure_oauth_client_id_var" {
  description = "Azure OAuth Client ID."
  type        = string
  sensitive   = true
}
variable "website_azure_oauth_client_secret_var" {
  description = "Azure OAuth Client Secret."
  type        = string
  sensitive   = true
}
variable "website_pusher_app_id_var" {
  description = "Pusher App ID."
  type        = string
  sensitive   = true
}
variable "website_pusher_app_key_var" {
  description = "Pusher App Key."
  type        = string
  sensitive   = true
}
variable "website_pusher_app_secret_var" {
  description = "Pusher App Secret."
  type        = string
  sensitive   = true
}
variable "website_reverb_app_id_var" {
  description = "Reverb App ID."
  type        = string
  sensitive   = true
}
variable "website_reverb_app_key_var" {
  description = "Reverb App Key."
  type        = string
  sensitive   = true
}
variable "website_reverb_app_secret_var" {
  description = "Reverb App Secret."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "arffornia_website_secret" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/website"
  data_json = jsonencode({
    APP_KEY                   = var.website_app_key_var
    AZURE_OAUTH_CLIENT_ID     = var.website_azure_oauth_client_id_var
    AZURE_OAUTH_CLIENT_SECRET = var.website_azure_oauth_client_secret_var
    PUSHER_APP_ID             = var.website_pusher_app_id_var
    PUSHER_APP_KEY            = var.website_pusher_app_key_var
    PUSHER_APP_SECRET         = var.website_pusher_app_secret_var
    REVERB_APP_ID             = var.website_reverb_app_id_var
    REVERB_APP_KEY            = var.website_reverb_app_key_var
    REVERB_APP_SECRET         = var.website_reverb_app_secret_var
  })
}

# --- Arffornia Database ---
variable "postgres_arffornia_user_var" {
  description = "Postgres username for the Arffornia database."
  type        = string
  sensitive   = true
}
variable "postgres_arffornia_password_var" {
  description = "Postgres password for the Arffornia database."
  type        = string
  sensitive   = true
}
variable "postgres_luckperms_user_var" {
  description = "Postgres username for the Luckperms database."
  type        = string
  sensitive   = true
}
variable "postgres_luckperms_password_var" {
  description = "Postgres password for the Luckperms database."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "postgres_arffornia_secret" {
  mount = vault_mount.kvv2.path
  name  = "postgres/arffornia"
  data_json = jsonencode({
    username = var.postgres_arffornia_user_var
    password = var.postgres_arffornia_password_var
  })
}

resource "vault_kv_secret_v2" "postgres_luckperms_secret" {
  mount = vault_mount.kvv2.path
  name  = "postgres/luckperms"
  data_json = jsonencode({
    username = var.postgres_luckperms_user_var
    password = var.postgres_luckperms_password_var
  })
}

# -----------------------------------------------------------------------------
# Adminer Secrets
# -----------------------------------------------------------------------------
variable "adminer_basic_auth_var" {
  description = "Basic auth credential for Adminer, created with `htpasswd`."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "adminer_basic_auth_secret" {
  mount = vault_mount.kvv2.path
  name  = "adminer/basic-auth"
  data_json = jsonencode({
    auth = var.adminer_basic_auth_var
  })
}

# -----------------------------------------------------------------------------
# CSI Driver SMB Secrets
# -----------------------------------------------------------------------------
variable "smb_nas_user_var" {
  description = "Username for SMB NAS."
  type        = string
  sensitive   = true
}
variable "smb_nas_password_var" {
  description = "Password for SMB NAS."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "smb_nas_credentials_secret" {
  mount = vault_mount.kvv2.path
  name  = "smb/nas-credentials"
  data_json = jsonencode({
    username = var.smb_nas_user_var
    password = var.smb_nas_password_var
  })
}

# -----------------------------------------------------------------------------
# Keycloak Secrets
# -----------------------------------------------------------------------------
variable "keycloak_admin_user_var" {
  description = "Admin username for Keycloak."
  type        = string
  sensitive   = true
}
variable "keycloak_admin_password_var" {
  description = "Admin password for Keycloak."
  type        = string
  sensitive   = true
}
variable "keycloak_epinaloa_client_secret_var" {
  description = "Client secret for the epinaloa realm in Keycloak."
  type        = string
  sensitive   = true
}
variable "postgres_keycloak_user_var" {
  description = "Postgres username for the Keycloak database."
  type        = string
  sensitive   = true
}
variable "postgres_keycloak_password_var" {
  description = "Postgres password for the Keycloak database."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "keycloak_admin_secret" {
  mount = vault_mount.kvv2.path
  name  = "keycloak/admin"
  data_json = jsonencode({
    username = var.keycloak_admin_user_var
    password = var.keycloak_admin_password_var
  })
}
resource "vault_kv_secret_v2" "keycloak_realm_secret" {
  mount = vault_mount.kvv2.path
  name  = "keycloak/epinaloa-realm-secret"
  data_json = jsonencode({
    client_secret = var.keycloak_epinaloa_client_secret_var
  })
}
resource "vault_kv_secret_v2" "postgres_keycloak_secret" {
  mount = vault_mount.kvv2.path
  name  = "postgres/keycloak"
  data_json = jsonencode({
    username = var.postgres_keycloak_user_var
    password = var.postgres_keycloak_password_var
  })
}

# -----------------------------------------------------------------------------
# Minio S3 Secrets
# -----------------------------------------------------------------------------
variable "minio_s3_root_user_var" {
  description = "Root username for Minio S3."
  type        = string
  sensitive   = true
}
variable "minio_s3_root_password_var" {
  description = "Root password for Minio S3."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "minio_s3_credentials_secret" {
  mount = vault_mount.kvv2.path
  name  = "minio-s3/credentials"
  data_json = jsonencode({
    rootUser     = var.minio_s3_root_user_var
    rootPassword = var.minio_s3_root_password_var
  })
}

# -----------------------------------------------------------------------------
# Monitoring Secrets
# -----------------------------------------------------------------------------
variable "grafana_admin_user_var" {
  description = "Admin username for Grafana."
  type        = string
  sensitive   = true
}
variable "grafana_admin_password_var" {
  description = "Admin password for Grafana."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "grafana_admin_secret" {
  mount = vault_mount.kvv2.path
  name  = "grafana/admin"
  data_json = jsonencode({
    "admin-user"     = var.grafana_admin_user_var
    "admin-password" = var.grafana_admin_password_var
  })
}

# -----------------------------------------------------------------------------
# N8n Secrets
# -----------------------------------------------------------------------------
variable "n8n_encryption_key_var" {
  description = "Encryption key for n8n."
  type        = string
  sensitive   = true
}
variable "postgres_n8n_user_var" {
  description = "Postgres username for the N8n database."
  type        = string
  sensitive   = true
}
variable "postgres_n8n_password_var" {
  description = "Postgres password for the N8n database."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "n8n_encryption_key_secret" {
  mount = vault_mount.kvv2.path
  name  = "n8n/encryption-key"
  data_json = jsonencode({
    key = var.n8n_encryption_key_var
  })
}
resource "vault_kv_secret_v2" "postgres_n8n_secret" {
  mount = vault_mount.kvv2.path
  name  = "postgres/n8n"
  data_json = jsonencode({
    username = var.postgres_n8n_user_var
    password = var.postgres_n8n_password_var
  })
}

# -----------------------------------------------------------------------------
# Nextcloud Secrets
# -----------------------------------------------------------------------------
variable "nextcloud_admin_user_var" {
  description = "Admin username for Nextcloud."
  type        = string
  sensitive   = true
}
variable "nextcloud_admin_password_var" {
  description = "Admin password for Nextcloud."
  type        = string
  sensitive   = true
}
variable "postgres_nextcloud_user_var" {
  description = "Postgres username for the Nextcloud database."
  type        = string
  sensitive   = true
}
variable "postgres_nextcloud_password_var" {
  description = "Postgres password for the Nextcloud database."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "nextcloud_admin_secret" {
  mount = vault_mount.kvv2.path
  name  = "nextcloud/admin"
  data_json = jsonencode({
    username = var.nextcloud_admin_user_var
    password = var.nextcloud_admin_password_var
  })
}
resource "vault_kv_secret_v2" "postgres_nextcloud_secret" {
  mount = vault_mount.kvv2.path
  name  = "postgres/nextcloud"
  data_json = jsonencode({
    username = var.postgres_nextcloud_user_var
    password = var.postgres_nextcloud_password_var
  })
}

# -----------------------------------------------------------------------------
# Plex Secrets
# -----------------------------------------------------------------------------
variable "plex_claim_token_var" {
  description = "Plex claim token for server setup."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "plex_claim_secret" {
  mount = vault_mount.kvv2.path
  name  = "plex/claim"
  data_json = jsonencode({
    token = var.plex_claim_token_var
  })
}

# -----------------------------------------------------------------------------
# Vaultwarden Secrets
# -----------------------------------------------------------------------------
variable "vaultwarden_admin_token_var" {
  description = "Admin token for Vaultwarden."
  type        = string
  sensitive   = true
}
variable "postgres_vaultwarden_user_var" {
  description = "Postgres username for the Vaultwarden database."
  type        = string
  sensitive   = true
}
variable "postgres_vaultwarden_password_var" {
  description = "Postgres password for the Vaultwarden database."
  type        = string
  sensitive   = true
}

resource "vault_kv_secret_v2" "vaultwarden_admin_secret" {
  mount = vault_mount.kvv2.path
  name  = "vaultwarden/admin"
  data_json = jsonencode({
    ADMIN_TOKEN = var.vaultwarden_admin_token_var
  })
}
resource "vault_kv_secret_v2" "postgres_vaultwarden_secret" {
  mount = vault_mount.kvv2.path
  name  = "postgres/vaultwarden"
  data_json = jsonencode({
    username = var.postgres_vaultwarden_user_var
    password = var.postgres_vaultwarden_password_var
  })
}

# -----------------------------------------------------------------------------
# Cert-Manager Secrets
# -----------------------------------------------------------------------------

resource "vault_kv_secret_v2" "cert_manager_cloudflare_api_token_secret" {
  mount = vault_mount.kvv2.path
  name  = "cert-manager/cloudflare-api-token"
  data_json = jsonencode({
    api-token = var.cloudflare_api_token_secret_var
  })
}
