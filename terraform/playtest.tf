# =============================================================================
# Spec 016 "Testable build": staging, the test slot and the website playtest slots
# (Arffornia/docs docs/specs/016-testable-build/spec.md). Everything here is new: a plan must
# show additions only. Kubernetes side: k8s/config/arffornia/{staging,slot,previews,playtest}.
#
# No prod value is reused. Every secret is generated here (random_*), except the optional
# "Arffornia Test" Microsoft app, which comes from the sops tfvars and defaults to empty.
# =============================================================================

# -----------------------------------------------------------------------------
# DNS
# -----------------------------------------------------------------------------

# Websites: DNS-only like the apex, served by the shared gateway (*.arffornia.com certificate).
resource "cloudflare_dns_record" "playtest_web" {
  for_each = toset(["staging", "pr1", "pr2", "pr3"])

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "CNAME"
  content = "origin.${var.domain_name}"
  ttl     = 1 # Auto
  proxied = false
}

# The test slot: Minecraft on TCP 25566 (router forward to the slot LoadBalancer) and its pack
# files on https://test.arffornia.com/pack/ (the gateway). DNS-only: Cloudflare's free plan
# cannot proxy raw TCP. An A record, like play.
resource "cloudflare_dns_record" "playtest_test_slot" {
  zone_id = var.cloudflare_zone_id
  name    = "test"
  type    = "A"
  content = var.dc_ip
  ttl     = 1 # Auto
  proxied = false
}

# -----------------------------------------------------------------------------
# Optional: the separate free "Arffornia Test" Microsoft app (decision D7), with redirect URIs
# on staging and pr1-pr3. Empty until it exists: Microsoft login then fails off prod, nothing else.
# -----------------------------------------------------------------------------

variable "website_test_azure_oauth_client_id_var" {
  description = "Client ID of the 'Arffornia Test' Microsoft app (staging and playtest slots only)."
  type        = string
  sensitive   = true
  default     = ""
}
variable "website_test_azure_oauth_client_secret_var" {
  description = "Client secret of the 'Arffornia Test' Microsoft app (staging and playtest slots only)."
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Generated values
# -----------------------------------------------------------------------------

# Laravel APP_KEY: "base64:" + 32 random bytes.
resource "random_bytes" "staging_app_key" {
  length = 32
}
resource "random_bytes" "previews_app_key" {
  length = 32
}

resource "random_password" "playtest" {
  for_each = toset(["staging_db", "staging_svc_id", "staging_svc_secret", "slot_rcon", "previews_db"])

  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Secrets (kvv2)
# -----------------------------------------------------------------------------

resource "vault_kv_secret_v2" "arffornia_staging_website" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/staging/website"
  data_json = jsonencode({
    APP_KEY                   = "base64:${random_bytes.staging_app_key.base64}"
    AZURE_OAUTH_CLIENT_ID     = var.website_test_azure_oauth_client_id_var
    AZURE_OAUTH_CLIENT_SECRET = var.website_test_azure_oauth_client_secret_var
  })
}

# The staging database: the website, and the test slot's Arffornia mod (web shop integration).
resource "vault_kv_secret_v2" "arffornia_staging_db" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/staging/db"
  data_json = jsonencode({
    username = "arffornia"
    password = random_password.playtest["staging_db"].result
  })
}

# The service account the test slot uses on the staging API (synced by the staging website).
resource "vault_kv_secret_v2" "arffornia_staging_svc" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/staging/svc"
  data_json = jsonencode({
    SVC_ID       = "staging-${random_password.playtest["staging_svc_id"].result}"
    SVC_PASSWORD = random_password.playtest["staging_svc_secret"].result
  })
}

resource "vault_kv_secret_v2" "arffornia_slot_server" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/slot/server"
  data_json = jsonencode({
    CFG_RCON_PASSWORD = random_password.playtest["slot_rcon"].result
  })
}

# Shared by the three website slots pr1-pr3 (each has its own seeded Postgres).
resource "vault_kv_secret_v2" "arffornia_previews_website" {
  mount = vault_mount.kvv2.path
  name  = "arffornia/previews/website"
  data_json = jsonencode({
    APP_KEY                   = "base64:${random_bytes.previews_app_key.base64}"
    DB_PASSWORD               = random_password.playtest["previews_db"].result
    AZURE_OAUTH_CLIENT_ID     = var.website_test_azure_oauth_client_id_var
    AZURE_OAUTH_CLIENT_SECRET = var.website_test_azure_oauth_client_secret_var
  })
}

# -----------------------------------------------------------------------------
# Policies and roles. Like every role here, they bind the Vault Secrets Operator's service
# account; Kyverno (k8s/config/kyverno/policy) limits which role and path each test namespace
# may use, so a test namespace can never read a prod path.
# -----------------------------------------------------------------------------

resource "vault_policy" "arffornia_staging_policy" {
  name = "arffornia-staging-policy"
  policy = templatefile("${path.module}/policies/arffornia_staging.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

resource "vault_policy" "arffornia_slot_policy" {
  name = "arffornia-slot-policy"
  policy = templatefile("${path.module}/policies/arffornia_slot.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

resource "vault_policy" "arffornia_previews_policy" {
  name = "arffornia-previews-policy"
  policy = templatefile("${path.module}/policies/arffornia_previews.hcl", {
    mount_path = vault_mount.kvv2.path
  })
}

resource "vault_kubernetes_auth_backend_role" "arffornia_staging_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "arffornia-staging-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.arffornia_staging_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "arffornia_slot_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "arffornia-slot-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.arffornia_slot_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "arffornia_previews_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "arffornia-previews-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400 # 24h
  token_policies                   = [vault_policy.arffornia_previews_policy.name]
}
