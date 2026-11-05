# =============================================================================
# MASTER REALM: ADMIN CONSOLE LOGIN
# Only the browser flow is managed here. The master realm itself is not a Terraform
# resource: importing it would put every one of its settings under this state.
#
# Password plus a security key (1Password passkey or YubiKey) on every admin console login.
# With no key registered yet, Keycloak asks the admin to register one at the next login.
# The relying party ID is left unset, so it is the host serving the login page, which is
# also where the key is registered.
#
# Terraform is not affected: the provider logs in through admin-cli and the direct grant
# flow, not the browser flow. Break-glass if the key is lost: `kc.sh bootstrap-admin user`
# in the Keycloak pod (README in k8s/config/keycloak/).
# Docs: https://www.keycloak.org/docs/latest/server_admin/index.html#webauthn_server_administration_guide
# =============================================================================

resource "keycloak_authentication_flow" "master_browser" {
  realm_id    = "master"
  alias       = "Browser-Master-Security-Key"
  description = "Admin console: password plus a mandatory security key"
}

resource "keycloak_authentication_execution" "master_cookie" {
  realm_id          = "master"
  parent_flow_alias = keycloak_authentication_flow.master_browser.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_subflow" "master_forms" {
  realm_id          = "master"
  parent_flow_alias = keycloak_authentication_flow.master_browser.alias
  alias             = "master-forms"
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution" "master_username_password" {
  realm_id          = "master"
  parent_flow_alias = keycloak_authentication_subflow.master_forms.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution" "master_security_key" {
  realm_id          = "master"
  parent_flow_alias = keycloak_authentication_subflow.master_forms.alias
  authenticator     = "webauthn-authenticator"
  requirement       = "REQUIRED"
  priority          = 20
}

resource "keycloak_required_action" "master_webauthn_register" {
  realm_id       = "master"
  alias          = "webauthn-register"
  name           = "Webauthn Register"
  enabled        = true
  default_action = false
}

resource "keycloak_authentication_bindings" "master" {
  realm_id     = "master"
  browser_flow = keycloak_authentication_flow.master_browser.alias

  depends_on = [
    keycloak_authentication_execution.master_cookie,
    keycloak_authentication_execution.master_username_password,
    keycloak_authentication_execution.master_security_key,
    keycloak_required_action.master_webauthn_register,
  ]
}
