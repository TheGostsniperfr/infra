output "arffornia_openid_client_id" {
  value       = keycloak_openid_client.arffornia_openid_client.client_id
  description = "Client ID for the Arffornia Envoy OIDC"
}

output "arffornia_openid_client_secret" {
  value       = keycloak_openid_client.arffornia_openid_client.client_secret
  sensitive   = true
  description = "Client Secret for the Arffornia Envoy OIDC"
}

output "oidc_issuer_url" {
  value       = "${var.keycloak_url}/realms/${keycloak_realm.arffornia.realm}"
  description = "The Issuer URL to put in your Envoy config"
}
