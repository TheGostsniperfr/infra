# =============================================================================
# Microsoft Entra app registrations for "Sign in with Microsoft" on the website
# (login.live.com, scope XboxLive.signin, then Xbox Live, XSTS and Minecraft services).
# The launcher is not concerned: msmc uses its own client id.
#
# Auth: the azuread provider uses the Azure CLI session. Run
#   az login --allow-no-subscriptions --tenant <tenant that owns the prod app>
# with the account that owns the app before plan or apply.
#
# Terraform cannot grant Minecraft API access. A new client id gets 403 on
# api.minecraftservices.com/authentication/login_with_xbox until Microsoft approves it
# through the review form https://aka.ms/mce-reviewappid (ops#14). See Readme.md.
# =============================================================================

provider "azuread" {
  tenant_id = var.azure_tenant_id_var != "" ? var.azure_tenant_id_var : null
}

variable "azure_tenant_id_var" {
  description = "Tenant that owns the Arffornia app registrations. Empty: the Azure CLI default tenant."
  type        = string
  default     = ""
}

variable "azure_prod_app_object_id_var" {
  # FILL ME: object id of the existing prod app ("Object ID" on the app's overview page, or
  # `az ad app list --display-name <name> --query '[].{name:displayName,objectId:id,clientId:appId}'`).
  # Empty: the prod app is not managed by Terraform yet.
  description = "Object id (not client id) of the existing prod website app registration, to import it."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Prod app: imported as is. ignore_changes = all keeps the first plans a no-op whatever its
# current settings are. To manage a field, copy its value from `terraform state show` into
# this block and remove that field from ignore_changes.
# -----------------------------------------------------------------------------

import {
  for_each = var.azure_prod_app_object_id_var != "" ? toset([var.azure_prod_app_object_id_var]) : toset([])
  to       = azuread_application.website_prod[0]
  id       = "/applications/${each.value}"
}

# Entra ID keeps a redirect URI collection per app, so it must be imported, not created.
import {
  for_each = var.azure_prod_app_object_id_var != "" ? toset([var.azure_prod_app_object_id_var]) : toset([])
  to       = azuread_application_redirect_uris.website_prod_web[0]
  id       = "/applications/${each.value}/redirectUris/Web"
}

resource "azuread_application" "website_prod" {
  count        = var.azure_prod_app_object_id_var != "" ? 1 : 0
  display_name = "Arffornia"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Shortcut until the "Arffornia Test" app is approved for Minecraft: staging and pr1-pr3 use the
# prod app, which is approved. Its web redirect URIs then also hold the test hosts; every other
# URI already on the app is kept as read. Switch back: set staging_uses_prod_microsoft_app_var to
# false and apply. The test URIs leave the prod app and the test app's id and secret go to Vault.
variable "staging_uses_prod_microsoft_app_var" {
  description = "Staging and pr1-pr3 sign in with the prod Microsoft app instead of 'Arffornia Test'."
  type        = bool
  default     = true
}

data "azuread_application" "website_prod" {
  count     = var.azure_prod_app_object_id_var != "" ? 1 : 0
  object_id = var.azure_prod_app_object_id_var
}

locals {
  website_test_redirect_uris = [for host in local.website_test_hosts : "https://${host}.${var.domain_name}/login/connect"]
  website_prod_other_redirect_uris = var.azure_prod_app_object_id_var != "" ? setsubtract(
    flatten([for web in data.azuread_application.website_prod[0].web : web.redirect_uris]),
    local.website_test_redirect_uris,
  ) : []
  staging_azure_client_id     = var.staging_uses_prod_microsoft_app_var ? var.website_azure_oauth_client_id_var : azuread_application.website_test.client_id
  staging_azure_client_secret = var.staging_uses_prod_microsoft_app_var ? var.website_azure_oauth_client_secret_var : azuread_application_password.website_test.value
}

# Owns the prod app's web redirect URIs (the app itself ignores all changes).
resource "azuread_application_redirect_uris" "website_prod_web" {
  count          = var.azure_prod_app_object_id_var != "" ? 1 : 0
  application_id = azuread_application.website_prod[0].id
  type           = "Web"
  redirect_uris = setunion(
    local.website_prod_other_redirect_uris,
    var.staging_uses_prod_microsoft_app_var ? local.website_test_redirect_uris : [],
  )
}

# -----------------------------------------------------------------------------
# "Arffornia Test" app (spec 016 decision D7): staging and the website playtest slots pr1-pr3.
# Same audience as a Minecraft login app: personal Microsoft accounts and work accounts.
# -----------------------------------------------------------------------------

locals {
  website_test_hosts = ["staging", "pr1", "pr2", "pr3"]
}

# Submit its client id at https://aka.ms/mce-reviewappid, then switch staging to it (see above).

resource "azuread_application" "website_test" {
  display_name     = "Arffornia Test"
  sign_in_audience = "AzureADandPersonalMicrosoftAccount"

  # Personal accounts require v2 access tokens.
  api {
    requested_access_token_version = 2
  }

  web {
    redirect_uris = local.website_test_redirect_uris
  }
}

# Rotated every year: the next apply after the date replaces the secret and Vault, and the
# staging pods pick it up through the Vault Secrets Operator.
resource "time_rotating" "website_test_secret" {
  rotation_days = 365
}

resource "azuread_application_password" "website_test" {
  application_id = azuread_application.website_test.id
  display_name   = "terraform"
  end_date       = timeadd(time_rotating.website_test_secret.rfc3339, "8760h")

  rotate_when_changed = {
    rotation = time_rotating.website_test_secret.id
  }
}
