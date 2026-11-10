################### A and AAAA Records ##################################

resource "cloudflare_dns_record" "arffornia_a_root_record" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "A"
  content = var.dc_ip
  ttl     = 1 # Auto
  proxied = false
}

# Grey-cloud name for the home IP. Every CNAME below targets it instead of the apex,
# so the apex can later be proxied by Cloudflare without breaking the DNS-only names
# (a DNS-only CNAME to a proxied apex would resolve to Cloudflare IPs that do not serve it).
resource "cloudflare_dns_record" "origin_a_record" {
  zone_id = var.cloudflare_zone_id
  name    = "origin"
  type    = "A"
  content = var.dc_ip
  ttl     = 1 # Auto
  proxied = false
}

#########################################################################

######################## Minecraft ######################################

# Minecraft and vote traffic is raw TCP: Cloudflare's free plan cannot proxy it,
# so it has its own DNS-only name. Players and vote sites use play.arffornia.com.
# An A record, not a CNAME: an SRV target must not be an alias (RFC 2782).
resource "cloudflare_dns_record" "minecraft_play_record" {
  zone_id = var.cloudflare_zone_id
  name    = "play"
  type    = "A"
  content = var.dc_ip
  ttl     = 1 # Auto
  proxied = false
}

# Lets players keep typing "arffornia.com" (no port): the Java client looks up
# _minecraft._tcp.<host> first. An explicit ":25565" skips this lookup.
resource "cloudflare_dns_record" "minecraft_srv_record" {
  zone_id  = var.cloudflare_zone_id
  name     = "_minecraft._tcp"
  type     = "SRV"
  ttl      = 1 # Auto
  priority = 0
  data = {
    priority = 0
    weight   = 5
    port     = 25565
    target   = "play.${var.domain_name}"
  }
}

#########################################################################

######################## CNAME Arffornia Cluster ########################

locals {
  cluster_cnames = {
    # Proxied (Orange Cloud)
    "adminer"        = true
    "argocd"         = true
    "grafana"        = true
    "longhorn"       = true
    "n8n"            = true
    "nextcloud"      = true
    "vault"          = true
    "vaultwarden"    = true
    "www"            = true
    "map"            = true
    "coder"          = true
    "offhours-guard" = true

    # DNS Only (Grey Cloud)
    "auth"       = false
    "admin-auth" = false
    "immich"     = false
    "ollama"     = false
    "ping"       = false
    "rcon"       = false
    "s3"         = false
    "noproxy"    = false
    "plex"       = false

    # DNS Only: Cloudflare caps request bodies at 100 MB (git push, docker push)
    # and cuts the long-lived KAS websockets
    "gitlab"          = false
    "gitlab-registry" = false
    "gitlab-kas"      = false
    "gitlab-ssh"      = false # Raw SSH on 5522, Cloudflare cannot proxy it
  }
}

resource "cloudflare_dns_record" "cluster_services" {
  for_each = local.cluster_cnames

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "CNAME"
  content = "origin.${var.domain_name}"
  ttl     = 1 # Auto
  proxied = each.value
}

#########################################################################

######################## CNAME Extra ####################################

# Portfolio
resource "cloudflare_dns_record" "about_dns_record" {
  zone_id = var.cloudflare_zone_id
  name    = "about"
  type    = "CNAME"
  content = "thegostsniperfr.github.io"
  ttl     = 1 # Auto
  proxied = false
}

# Coder wildcard
resource "cloudflare_dns_record" "coder_wildcard_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "*.coder"
  type    = "CNAME"
  content = "origin.${var.domain_name}"
  ttl     = 1
  proxied = true
}

#########################################################################

######################## Zone settings ##################################

# Full (strict): Cloudflare reaches the origin over HTTPS and checks its certificate (the Let's
# Encrypt wildcard of the shared-gateway). It was Flexible: proxied traffic reached the origin in
# clear text on port 80, and a gateway-side HTTP to HTTPS redirect would loop.
# https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Proxied names: Cloudflare redirects HTTP to HTTPS itself. DNS-only names are redirected by the
# shared-gateway (k8s/config/gateway-infra).
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "always_use_https"
  value      = "on"
}

#########################################################################
