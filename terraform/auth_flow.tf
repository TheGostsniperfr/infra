# =============================================================================
# ROLES & GROUP MAPPINGS
# =============================================================================

# Role required to access Arffornia Apps
resource "keycloak_role" "openid_client_access" {
  realm_id    = keycloak_realm.arffornia.id
  name        = "openid_client_access"
  description = "Role required to access Arffornia Apps"
}

# Authorize the 'member' group
resource "keycloak_group_roles" "member_app_access" {
  realm_id = keycloak_realm.arffornia.id
  group_id = keycloak_group.member.id
  role_ids = [keycloak_role.openid_client_access.id]
}

# =============================================================================
# BROWSER FLOW v5: PASSKEY FIRST
# Docs: https://www.keycloak.org/docs/latest/server_admin/index.html#passkeys_server_administration_guide
#
# The username/password form also offers the passkey (conditional UI and a "Sign in with
# Passkey" button) once passwordless_passkeys_enabled is set on the realm. A passkey already
# proves possession and user verification, so the second factor is skipped after one. The
# password path keeps a mandatory second factor: OTP, security key or a recovery code.
# =============================================================================

resource "keycloak_authentication_flow" "browser_v5" {
  realm_id    = keycloak_realm.arffornia.id
  alias       = "Browser-Arffornia-Login-v5"
  description = "Passkey first, password plus second factor as fallback, then RBAC"
}

resource "keycloak_authentication_subflow" "v5_login" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_flow.browser_v5.alias
  alias             = "arffornia-v5-login"
  provider_id       = "basic-flow"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution" "v5_cookie" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_login.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

resource "keycloak_authentication_subflow" "v5_forms" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_login.alias
  alias             = "arffornia-v5-forms"
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution" "v5_username_password" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_forms.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# Runs when the user has a second factor configured and did not log in with a passkey.
# A user with no second factor yet skips it, then the CONFIGURE_TOTP required action makes them
# set one up before the session opens. Without the user-configured condition the alternatives
# below all fail with "credential setup required" and the first login of a new account errors.
resource "keycloak_authentication_subflow" "v5_second_factor" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_forms.alias
  alias             = "arffornia-v5-second-factor"
  provider_id       = "basic-flow"
  requirement       = "CONDITIONAL"
  priority          = 20
}

resource "keycloak_authentication_execution" "v5_condition_user_configured" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_second_factor.alias
  authenticator     = "conditional-user-configured"
  requirement       = "REQUIRED"
  priority          = 5
}

resource "keycloak_authentication_execution" "v5_condition_no_passkey" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_second_factor.alias
  authenticator     = "conditional-credential"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution_config" "v5_condition_no_passkey" {
  realm_id     = keycloak_realm.arffornia.id
  execution_id = keycloak_authentication_execution.v5_condition_no_passkey.id
  alias        = "v5-second-factor-unless-passkey"
  config = {
    credentials = "webauthn-passwordless"
    included    = "false"
  }
}

resource "keycloak_authentication_execution" "v5_otp" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_second_factor.alias
  authenticator     = "auth-otp-form"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

resource "keycloak_authentication_execution" "v5_security_key" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_second_factor.alias
  authenticator     = "webauthn-authenticator"
  requirement       = "ALTERNATIVE"
  priority          = 30
}

resource "keycloak_authentication_execution" "v5_recovery_code" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_second_factor.alias
  authenticator     = "auth-recovery-authn-code-form"
  requirement       = "ALTERNATIVE"
  priority          = 40
}

resource "keycloak_authentication_subflow" "v5_rbac" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_flow.browser_v5.alias
  alias             = "arffornia-v5-rbac"
  provider_id       = "basic-flow"
  requirement       = "CONDITIONAL"
  priority          = 20
}

resource "keycloak_authentication_execution" "v5_condition_role" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_rbac.alias
  authenticator     = "conditional-user-role"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution_config" "v5_condition_role" {
  realm_id     = keycloak_realm.arffornia.id
  execution_id = keycloak_authentication_execution.v5_condition_role.id
  alias        = "v5-deny-if-not-arffornia-access"
  config = {
    condUserRole = keycloak_role.openid_client_access.name
    negate       = "true"
  }
}

resource "keycloak_authentication_execution" "v5_deny_access" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.v5_rbac.alias
  authenticator     = "deny-access-authenticator"
  requirement       = "REQUIRED"
  priority          = 20
}

# Realm-wide binding: every client gets the same MFA and the same RBAC check, with no
# per-client override to forget on a new client.
resource "keycloak_authentication_bindings" "arffornia" {
  realm_id     = keycloak_realm.arffornia.id
  browser_flow = keycloak_authentication_flow.browser_v5.alias
}
