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
# PHASE 0: ROOT AUTHENTICATION FLOW
# =============================================================================

resource "keycloak_authentication_flow" "browser_openid_client" {
  realm_id    = keycloak_realm.arffornia.id
  alias       = "Browser-Arffornia-Login-v4"
  description = "Complete Flow: Authentication Wrapper followed by RBAC Wrapper"
}

# =============================================================================
# PHASE 1: LOGIN WRAPPER
# Groups every authentication method.
# If ANY method succeeds, the user is authenticated.
# =============================================================================

resource "keycloak_authentication_subflow" "login_wrapper" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_flow.browser_openid_client.alias
  alias             = "arffornia-login-wrapper"
  provider_id       = "basic-flow"
  requirement       = "REQUIRED"
  priority          = 10
}

# =============================================================================
# PHASE 1.1: SSO AUTHENTICATION METHODS
# =============================================================================

# Checks if the user already has a valid Keycloak SSO cookie.
# If yes, login is transparent.
resource "keycloak_authentication_execution" "cookie" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

# Checks for Kerberos ticket (Active Directory SSO)
resource "keycloak_authentication_execution" "kerberos" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  authenticator     = "auth-spnego"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

# Redirect to external identity provider if configured
resource "keycloak_authentication_execution" "idp_redirector" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 30
}

# =============================================================================
# PHASE 1.2: MANUAL LOGIN FALLBACK
# If no SSO method worked, fallback to username/password login
# =============================================================================

resource "keycloak_authentication_subflow" "forms_wrapper" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  alias             = "arffornia-forms-wrapper"
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"
  priority          = 40
}

# Standard Keycloak login page
resource "keycloak_authentication_execution" "username_password" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.forms_wrapper.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# =============================================================================
# PHASE 1.3: MULTI FACTOR AUTHENTICATION
# Triggered after successful username/password authentication. Mandatory for all.
# =============================================================================

resource "keycloak_authentication_subflow" "mandatory_otp" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.forms_wrapper.alias
  alias             = "arffornia-mandatory-otp"
  provider_id       = "basic-flow"
  requirement       = "REQUIRED"
  priority          = 20
}

# Ask for OTP token. If the user doesn't have one configured,
# Keycloak will automatically force them to set it up (QR Code screen).
resource "keycloak_authentication_execution" "otp_form" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.mandatory_otp.alias
  authenticator     = "auth-otp-form"
  requirement       = "REQUIRED"
  priority          = 10
}
# =============================================================================
# PHASE 2: RBAC WRAPPER
# The user is authenticated at this point.
# We now verify if the user is authorized to access the application.
# =============================================================================

resource "keycloak_authentication_subflow" "rbac_deny_wrapper" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_flow.browser_openid_client.alias
  alias             = "arffornia-rbac-deny-wrapper"
  provider_id       = "basic-flow"
  requirement       = "CONDITIONAL"
  priority          = 20
}

# Check if user has required role
resource "keycloak_authentication_execution" "condition_role" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.rbac_deny_wrapper.alias
  authenticator     = "conditional-user-role"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution_config" "condition_role_config" {
  realm_id     = keycloak_realm.arffornia.id
  execution_id = keycloak_authentication_execution.condition_role.id
  alias        = "deny-if-not-arffornia-access"

  config = {
    condUserRole = keycloak_role.openid_client_access.name
    negate       = "true"
  }
}

# If user does NOT have required role -> deny access
resource "keycloak_authentication_execution" "deny_access" {
  realm_id          = keycloak_realm.arffornia.id
  parent_flow_alias = keycloak_authentication_subflow.rbac_deny_wrapper.alias
  authenticator     = "deny-access-authenticator"
  requirement       = "REQUIRED"
  priority          = 20
}
