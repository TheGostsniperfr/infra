# Keycloak

Keycloak 26.5 from the codecentric `keycloakx` chart (`values.yaml`), PostgreSQL from the
operator (`postgres.yaml`). The realm `arffornia` (flows, clients, users, WebAuthn policies) and
the browser flow of `master` are Terraform (`terraform/main.tf`, `auth_flow.tf`,
`master_realm.tf`). The login and account themes come from
[keycloak-theme-arffornia](https://github.com/Arffornia/keycloak-theme-arffornia), copied into
`/providers` by the `theme-provider-init` init container.

| Host | What |
|---|---|
| `auth.arffornia.com` | Realm endpoints, login pages, account console |
| `admin-auth.arffornia.com` | Admin console (`master` realm) |

## How a user signs in

- **Passkey first.** The username field offers the passkey (conditional UI), and the
  "Sign in with Passkey" button opens the browser prompt. A passkey skips the second factor.
- **Password fallback.** Password, then OTP, a security key (YubiKey) or a recovery code.
- **First login of a new account.** Password, then the required actions: OTP, recovery codes,
  passkey, new password. The session only opens once they are done.
- **Every client** (ArgoCD, GitLab, Vault, Longhorn, Adminer) uses the same flow, bound at the
  realm level. Users without the role `openid_client_access` are denied.
- **Admin console.** Password plus a mandatory security key. Terraform is not affected: the
  provider uses `admin-cli` and the direct grant flow.

## Rolling out passkeys (order matters)

1. Release the theme: merge the theme PRs, then tag `v1.1.0` in `keycloak-theme-arffornia`.
   The theme must ship the conditional UI fix (`fix(theme): stop the passkey autofill request
   from reloading the page`) **before** passkeys are enabled: the older theme reloads the login
   page endlessly when a browser rejects the autofill request.
2. Merge the infra PR that pins `keycloak-theme-arffornia:1.1.0`. Argo CD restarts Keycloak.
   Check that the login page shows the factory line.
3. Apply `feat(keycloak): add passkey-first browser flow v5`. The flow is only bound to the
   client `arffornia-openid` at this point.
4. On `https://auth.arffornia.com/realms/arffornia/account`, Account security, Signing in:
   register a passkey (1Password or the platform), a security key (YubiKey, under
   two-factor authentication), and recovery codes. Store the codes in 1Password.
5. Test on Longhorn in a private window: passkey only, then password plus OTP, then password
   plus a recovery code.
6. Apply `feat(keycloak): make flow v5 the realm browser flow`. Test ArgoCD, GitLab and Vault.
7. Apply `feat(keycloak): require a security key on the master realm`. Keep an admin console
   session open in another browser during the apply. At the next admin login, register the
   YubiKey or a 1Password passkey when asked.
8. Apply `feat(keycloak): longer remember-me sessions and NIST password policy`.
9. Vault step-up (`feat(vault): manage the OIDC login role...`): first
   `vault read auth/oidc/role/default` and align `vault_jwt_auth_backend_role.oidc_default`
   so `terraform plan` shows the import plus `max_age` only. Then every `vault login` asks for a
   fresh passkey touch.

## Break-glass

- **Locked out of the `arffornia` realm:** the admin console (`master`) still works; switch the
  realm browser flow back in the UI to unblock, then revert the PR and `terraform apply` so the
  state matches again.
- **Lost the admin security key:** create a temporary admin from inside the pod, log in with
  it, remove the old key from the `admin` user, then delete the temporary admin.
  ```sh
  kubectl exec -it -n keycloak keycloakx-0 -- /opt/keycloak/bin/kc.sh bootstrap-admin user
  ```
  Doc: https://www.keycloak.org/server/bootstrap-admin-recovery

## Not done yet

- **Terraform provider login.** Still a password through `admin-cli`. A `master` client with
  a service account and `client_credentials` would remove the admin password from the tfvars.
- **Security alert emails** need an SMTP relay.
