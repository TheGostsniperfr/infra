output "openid_client_id" {
  value       = keycloak_openid_client.openid_client.client_id
  description = "Client ID for the Envoy Native OIDC"
}

output "openid_client_secret" {
  value       = keycloak_openid_client.openid_client.client_secret
  sensitive   = true
  description = "Client Secret for the Envoy Native OIDC"
}

output "oidc_issuer_url" {
  value       = "${var.keycloak_url}/realms/${keycloak_realm.arffornia.realm}"
  description = "The Issuer URL to put in your Envoy config"
}
