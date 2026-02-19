################### A and AAAA Records ##################################

resource "cloudflare_dns_record" "arffornia_a_root_record" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "A"
  content = var.dc_ip
  ttl     = 1 # Auto
  proxied = false
}

#########################################################################

######################## CNAME Arffornia Cluster ########################

locals {
  cluster_cnames = {
    # Proxied (Orange Cloud)
    "adminer"     = true
    "argocd"      = true
    "grafana"     = true
    "longhorn"    = true
    "n8n"         = true
    "nextcloud"   = true
    "vault"       = true
    "vaultwarden" = true
    "www"         = true
    "map"         = true
    "coder"       = true

    # DNS Only (Grey Cloud)
    "auth"    = false
    "ollama"  = false
    "ping"    = false
    "rcon"    = false
    "s3"      = false
    "noproxy" = false
    "plex"    = false
  }
}

resource "cloudflare_dns_record" "cluster_services" {
  for_each = local.cluster_cnames

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "CNAME"
  content = var.domain_name
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
  content = var.domain_name
  ttl     = 1
  proxied = true
}

#########################################################################
