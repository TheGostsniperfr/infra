# -----------------------------------------------------------------------------
# REALM CONFIGURATION
# -----------------------------------------------------------------------------
resource "keycloak_realm" "arffornia" {
  realm             = "arffornia"
  enabled           = true
  display_name      = "Arffornia ID"
  display_name_html = "<b>Arffornia ID</b>"

  terraform_deletion_protection = false # When set to true, the realm cannot be deleted. Defaults to false.

  # Theme
  login_theme = "arffornia"
  # account_theme = "base"
  # admin_theme   = "base"
  # email_theme   = "base"

  # Best practices for token security
  access_code_lifespan     = "1h"  # The maximum amount of time a client has to finish the authorization code flow.
  access_token_lifespan    = "1h"  # The amount of time an access token can be used before it expires.
  sso_session_idle_timeout = "10h" # The amount of time a session can be idle before it expires. ?
  sso_session_max_lifespan = "24h" # The maximum amount of time before a session expires regardless of activity.

  # Enable user registration for testing (optional)
  login_with_email_allowed = true
  registration_allowed     = false
  reset_password_allowed   = false # When true, a "forgot password" link will be displayed on the login page.
  remember_me              = true  # When true, a "remember me" checkbox will be displayed on the login page, and the user's session will not expire between browser restarts.
  verify_email             = false # When true, users are required to verify their email address after registration and after email address changes.
  duplicate_emails_allowed = false # When true, multiple users will be allowed to have the same email address. This argument must be set to false if login_with_email_allowed is set to true.

  ssl_required    = "external"
  password_policy = "upperCase(1) and length(8) and forceExpiredPasswordChange(365) and notUsername"
  # attributes = {
  #   mycustomAttribute = "myCustomValue"
  # }

  # TODO Check what are the meaning of all those settings
  security_defenses {
    headers {
      x_frame_options                     = "DENY"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }
    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 30
      wait_increment_seconds           = 60
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }

  # Passkeys: https://www.keycloak.org/docs/latest/server_admin/index.html#passkeys_server_administration_guide
  # The RP ID is the registrable domain, not auth.<domain>, so passkeys survive a Keycloak
  # hostname change. Changing it later invalidates every registered passkey.
  web_authn_passwordless_policy {
    relying_party_entity_name         = "Arffornia ID"
    relying_party_id                  = var.base_domain
    signature_algorithms              = ["ES256", "RS256"]
    user_verification_requirement     = "required"
    require_resident_key              = "Yes"
    attestation_conveyance_preference = "none"
    avoid_same_authenticator_register = true
    passwordless_passkeys_enabled     = true
  }

  # Security key (YubiKey) as a second factor after a password.
  web_authn_policy {
    relying_party_entity_name         = "Arffornia ID"
    relying_party_id                  = var.base_domain
    signature_algorithms              = ["ES256", "RS256"]
    user_verification_requirement     = "preferred"
    attestation_conveyance_preference = "none"
    avoid_same_authenticator_register = true
  }
}

resource "keycloak_required_action" "webauthn_register_passwordless" {
  realm_id       = keycloak_realm.arffornia.id
  alias          = "webauthn-register-passwordless"
  name           = "Webauthn Register Passwordless"
  enabled        = true
  default_action = true
}

resource "keycloak_required_action" "webauthn_register" {
  realm_id       = keycloak_realm.arffornia.id
  alias          = "webauthn-register"
  name           = "Webauthn Register"
  enabled        = true
  default_action = false
}

resource "keycloak_required_action" "recovery_codes" {
  realm_id       = keycloak_realm.arffornia.id
  alias          = "CONFIGURE_RECOVERY_AUTHN_CODES"
  name           = "Recovery Authentication Codes"
  enabled        = true
  default_action = true
}

resource "keycloak_required_action" "totp" {
  realm_id       = keycloak_realm.arffornia.id
  alias          = "CONFIGURE_TOTP"
  enabled        = true
  default_action = true
  name           = "Configure OTP"
}

resource "keycloak_realm_user_profile" "arffornia_profile" {
  realm_id = keycloak_realm.arffornia.id

  attribute {
    name         = "username"
    display_name = "$${username}"
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
  }

  attribute {
    name         = "email"
    display_name = "$${email}"
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
  }

  attribute {
    name         = "firstName"
    display_name = "$${firstName}"
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
  }

  attribute {
    name         = "lastName"
    display_name = "$${lastName}"
    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }
  }

  attribute {
    name         = "picture"
    display_name = "Profile Picture URL"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "uri"
    }
  }
}
