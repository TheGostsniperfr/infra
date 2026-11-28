# edge: the always-on entry point of the LAN, a NixOS LXC (hosts/edge in the dotfiles flake).
# It is a Tailscale subnet router for 192.168.1.0/24, so nothing else needs a port forward
# on the box to be reached from outside. Address from docs/network/ip-plan.md.

resource "proxmox_virtual_environment_file" "edge_template" {
  node_name    = var.proxmox_node
  datastore_id = "local"
  content_type = "vztmpl"

  source_file {
    path      = var.edge_template_path
    file_name = "nixos-edge.tar.xz"
  }

  # The image only seeds the container. Its system is updated with nixos-rebuild afterwards,
  # so a new build must not replace the template, nor the container through it.
  lifecycle {
    ignore_changes = [source_file]
  }
}

resource "proxmox_virtual_environment_container" "edge" {
  node_name     = var.proxmox_node
  vm_id         = 113
  description   = "Tailscale subnet router. Managed by arffornia/infra terraform/homelab and the dotfiles host edge."
  tags          = ["terraform", "nixos"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  operating_system {
    template_file_id = proxmox_virtual_environment_file.edge_template.id
    type             = "nixos"
  }

  # Nix needs nesting for its build sandbox. It is the only feature a non-root token may set.
  features {
    nesting = true
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 16
  }

  # Fixed MAC: the box has a static DHCP rule for it on .4, which is still inside its pool.
  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "BC:24:11:ED:6E:04"
  }

  # Proxmox writes these into the container as systemd-networkd files.
  initialization {
    hostname = "edge"

    ip_config {
      ipv4 {
        address = "192.168.1.4/24"
        gateway = "192.168.1.254"
      }
    }

    dns {
      servers = ["192.168.1.254"]
    }
  }

  startup {
    order = 1
  }

  lifecycle {
    ignore_changes = [operating_system[0].template_file_id]
  }
}
