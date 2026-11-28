# LAN IP plan: 192.168.1.0/24

The single source of truth for who owns which address on the home LAN. Change this file in the
same PR as anything that pins an IP (MetalLB, SMB sources, `Endpoints`, Terraform).

The Bbox (Bouygues F@st5688b) is the router, the DNS and the DHCP server. It has no VLANs.
Static addresses are DHCP reservations on the box (Réglages avancés > DHCP IPv4 > static IP rules),
except MetalLB addresses, which are never leased.

## Ranges

| Range | Role | Assigned |
|---|---|---|
| `.1-.9` | Network gear and always-on services | `.2` switch TL-SG105E, `.4` edge (LXC, Tailscale subnet router) |
| `.10-.19` | Physical hosts | `.10` Proxmox, `.11-.13` OpenStack pae-node-1..3 |
| `.20-.29` | Personal machines and VMs | `.20` Windows-SSD (GPU, Ollama, photo-ai runner), `.21` NixOS workstation, `.22` jumpserver |
| `.30-.39` | Kubernetes prod | `.30` master-node, `.31-.33` worker-01..03 |
| `.40-.49` | Kubernetes test | `test-k8s-*` VMs |
| `.50-.69` | Lab VMs | `server`, `node-0`, `node-1` |
| `.70-.99` | Free | |
| `.100-.199` | DHCP pool | phones, laptops, guests. Nothing pinned here |
| `.200-.229` | OpenStack | VMs and floating IPs |
| `.230-.239` | Free | |
| `.240-.253` | MetalLB | see below |
| `.254` | Bbox | |

## MetalLB (`k8s/config/metallb/metallb-pool.yaml`)

Every LoadBalancer pins its address with `metallb.universe.tf/loadBalancerIPs`.

| IP | Service | Port forward on the box |
|---|---|---|
| `.240` | `gitlab/gitlab-gitlab-shell` | TCP 5522 |
| `.241` | `envoy-gateway-system/envoy-gateway-infra-shared-gateway` | 80, 443 |
| `.242` | `arffornia-proxy-velocity/...-minecraft-proxy` | 25565 |
| `.243` | `arffornia-proxy-velocity/...-nuvotifier` | 8192 |
| `.244` | left out of the pool on purpose | |
| `.245` | `arffornia-slot/test-slot-minecraft` | 25566 |
| `.246` | `postgres/postgres-lb` | none, LAN only |
| `.247-.250` | free, in the pool | |
| `.251-.253` | reserved for the pool, not in it yet | |

## Migration status

The plan was adopted on 2026-11-28. Until each move is done, the current address stays in use:

| Host | Now | Target | Notes |
|---|---|---|---|
| switch TL-SG105E | `.31` (DHCP) | `.2` | |
| Proxmox | `.49` | `.10` | On site only: a mistake in `/etc/network/interfaces` cuts remote access. Same PR updates the SMB sources in `csi-driver-smb`, `immich` and `docs/runbooks` |
| pae-node-1..3 | `.110 .81 .47` | `.11-.13` | After reviewing the OpenStack deployment: endpoints and the WireGuard mesh use these IPs |
| workstation | `.86` (DHCP) | `.21` | |
| master-node | `.73` | `.30` | kubeadm control plane: apiserver certificate SANs, etcd and kubeconfigs must be regenerated |
| worker-01..03 | `.168 .142 .127` | `.31-.33` | DHCP reservation, then reboot the node |
| DHCP pool | `.1-.199` | `.100-.199` | Last, once nothing pinned is left inside `.100-.199` |
