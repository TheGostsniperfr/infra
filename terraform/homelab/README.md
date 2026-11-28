# terraform/homelab: Proxmox and Tailscale

A Terraform root separate from `../`, so that changing a Proxmox guest does not need Vault,
Keycloak or Cloudflare. It manages:

- `edge` (`edge.tf`): the always-on NixOS LXC, Tailscale subnet router for `192.168.1.0/24`.
  Its system comes from the dotfiles host `hosts/edge`.
- the tailnet policy and edge's auth key (`tailscale.tf`).

Same rules as `../`: Terraform runs on Brian's machine only, the state is in Garage
(`tf-state`, key `homelab/terraform.tfstate`, credentials as in `../Readme.md`), and secrets
come from a sops file decrypted on the fly.

The state lives in Garage, inside the cluster that runs on this Proxmox. Changing guests needs
the cluster up. Running them does not: the Proxmox UI is the fallback.

## One-time setup

### 1. Proxmox user and token

The token is not `root@pam`, so two things are out of reach: device passthrough (edge uses
Tailscale's userspace networking instead of `/dev/net/tun`) and LXC features other than
`nesting`. As root on the Proxmox host:

```sh
pveum role add Terraform -privs "Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Mapping.Audit,Mapping.Use,Pool.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.GuestAgent.Audit,VM.Migrate,VM.PowerMgmt"
pveum user add terraform@pve --comment "arffornia/infra terraform/homelab"
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve homelab --privsep 0
```

The last command prints the token secret once.

### 2. Tailscale OAuth client

1. In the admin console, Access controls: add `"tagOwners": {"tag:subnet-router": ["autogroup:admin"]}`.
   An OAuth client can only be given a tag that already exists. Terraform owns the policy afterwards.
2. Settings > OAuth clients > Generate: scopes **Policy File: write** and **Auth Keys: write**,
   tag `tag:subnet-router`.

### 3. Secrets

The values go in `~/.dotfiles/secrets/homelab-tfvars.json`, a sops binary file for the same
post-quantum recipient as `arffornia-tfvars.json` (see the dotfiles `.sops.yaml`):

```sh
sops --input-type json ~/.dotfiles/secrets/homelab-tfvars.json
```

Put the tfvars content in the `data` field:

```hcl
proxmox_api_token             = "terraform@pve!homelab=<secret>"
tailscale_oauth_client_id     = "<id>"
tailscale_oauth_client_secret = "<secret>"
```

### 4. Box

Réglages avancés > DHCP IPv4 > static IP rule: MAC `BC:24:11:ED:6E:04` on `192.168.1.4`. The
address is inside the box's DHCP pool until the pool shrinks (`docs/network/ip-plan.md`), and the
rule keeps it from being leased to another device.

## Plan and apply

```sh
cd terraform/homelab
set -a; . ~/.config/arffornia/tf-backend.env; set +a
export SSL_CERT_DIR=$PWD/certs   # Proxmox API is signed by its cluster CA, kept TLS-verified
nix build ~/.dotfiles#nixosConfigurations.edge.config.system.build.tarball -o .edge-template
terraform init
terraform plan  -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/homelab-tfvars.json)
terraform apply -var-file=<(sops decrypt --input-type json --output-type binary ~/.dotfiles/secrets/homelab-tfvars.json)
```

`certs/pve-root-ca.pem` is the Proxmox cluster CA, public. If the host changes its address,
`pvecm updatecerts --force` regenerates the node certificate and `proxmox_endpoint` changes.

The first plan imports the current tailnet policy and shows the diff to `tailscale.tf`: read it
before applying.

## edge

### First boot

The auth key is single use and only needed once:

```sh
terraform output -raw edge_tailscale_auth_key \
  | ssh root@192.168.1.4 'tailscale up --auth-key=file:/dev/stdin --advertise-routes=192.168.1.0/24'
```

The route is approved by `autoApprovers`. In the Tailscale app, enable "Use Tailscale subnets"
where the client does not accept routes by default (Linux: `tailscale set --accept-routes`).

### Updates

The template only seeds the container. Its system changes through the dotfiles:

```sh
nixos-rebuild switch --flake ~/.dotfiles#edge --target-host root@192.168.1.4
```

### Turning it on from outside

edge starts with the host (`start_on_boot`, startup order 1). The host is woken by the Bbox
WOL proxy (Réglages avancés > Accès à distance, ports 7 and 9).

## Manual steps that stay manual

- Tailnet Lock: enabled from trusted devices (`tailscale lock init`), it cannot be done by Terraform.
