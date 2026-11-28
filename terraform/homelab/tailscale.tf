# Tailnet policy: https://tailscale.com/kb/1337/policy-syntax
# Subnet routers: https://tailscale.com/kb/1019/subnets

import {
  to = tailscale_acl.this
  id = "acl"
}

resource "tailscale_acl" "this" {
  acl = jsonencode({
    tagOwners = {
      "tag:subnet-router" = ["autogroup:admin"]
    }

    # edge's route is approved without a click in the admin console.
    autoApprovers = {
      routes = {
        "192.168.1.0/24" = ["tag:subnet-router"]
      }
    }

    # Only Brian's devices are members: they reach everything, the LAN included.
    # Tagged devices get no grant, so edge cannot open connections to them.
    grants = [
      {
        src = ["autogroup:member"]
        dst = ["*"]
        ip  = ["*"]
      },
    ]

    ssh = [
      {
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      },
    ]
  })
}

# Single use: it only joins edge to the tailnet once (README.md, "First boot"). Tagged devices
# have no key expiry, so edge stays logged in afterwards.
resource "tailscale_tailnet_key" "edge" {
  description         = "edge subnet router"
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  expiry              = 86400
  tags                = ["tag:subnet-router"]
  recreate_if_invalid = "never"

  depends_on = [tailscale_acl.this]
}

output "edge_tailscale_auth_key" {
  value     = tailscale_tailnet_key.edge.key
  sensitive = true
}
