# App platform: security and isolation

What protects the cluster and the teams from each other, and what does not. Written to be
presented: each control names the file that enforces it. How to use the platform: [`GUIDE.md`](GUIDE.md).

## The model

```
 Developer ──MR──▶ main ──pipeline──▶ build ─▶ sign (Vault) ─▶ release
                                        │                         │
                                        ▼                         ▼
                                  GitLab registry         deploy repository
                                        ▲                         ▲
                                        │ pull, verify signature  │ pull
                                     Kyverno ◀── Pod ◀── Argo CD ─┘
```

1. A pipeline never touches the cluster. It builds an image, has Vault sign it, and writes the
   digest to the app's `deploy` repository.
2. Argo CD, inside the cluster, pulls that repository and renders the **platform's** chart with
   it. Teams write values, never manifests.
3. Before a Pod starts, Kyverno checks that the image is the app's own and signed by the app's
   key. That key lives in Vault and only a pipeline on the app's `main` may use it.

So to run code in production, someone must get it merged to `main`. Pushing an image, writing to
the `deploy` repository, or stealing a GitLab token is not enough.

## Who can do what

| Actor | Can | Cannot |
|---|---|---|
| Developer | Push branches, open MRs, run branch pipelines, push to the registry | Merge to `main`, sign, deploy |
| Maintainer | Merge to `main`, so deploy. Edit `deploy` directly | Sign outside a `main` pipeline, change anything in the cluster beyond `deploy.yaml`'s keys |
| Branch or MR pipeline | Test, check `deploy.yaml` | See `DEPLOY_REPO_TOKEN`, log in to Vault's signing role |
| `main` pipeline | Sign with its app's key, write its app's `deploy` repository | Reach the cluster API, the LAN, another app's key |
| Argo CD, for an app | Create Deployments, Services, HTTPRoutes, VaultSecrets in `<team>-<app>` | Anything else, anywhere else |
| Platform admin | Everything: Terraform, Argo CD, the cluster | |

## Controls, layer by layer

| Layer | Control | Where |
|---|---|---|
| GitLab | `main` protected: Maintainers only push and merge | GitLab default branch protection |
| GitLab | Groups and projects private; teams are members of `apps/<team>` only | `terraform/gitlab.tf` |
| GitLab | Agents have no CI access: no pipeline can reach the cluster | `terraform/gitlab.tf` |
| CI | Builds without privileges (Kaniko) | `.gitlab-ci.yml` of the templates |
| CI | Jobs in `gitlab-ci-jobs`: nothing reaches them, they reach DNS and the internet only | `k8s/config/gitlab/ci-jobs-namespace.yaml` |
| Vault | Signing key never leaves Vault; role bound to `namespace_path`, `ref=main`, `ref_protected=true`; token valid 5 minutes | `terraform/apps.tf` |
| Vault | Each app namespace reads only its own path, through a role Kyverno pins | `terraform/apps.tf`, `guardrails.yaml` |
| Argo CD | One project per app: one namespace, 4 kinds, no cluster-scoped object | `charts/gitlab-team/templates/argocd.yaml` |
| Chart | Values limited by a schema; security context, image path, service account fixed | `charts/app` |
| Admission | Images: the app's registry path only, plus the database image | `guardrails.yaml`, rule `images` |
| Admission | Images signed by the app's key | rule `signed-images` |
| Admission | Pod Security `restricted`; `baseline` also enforced by Kubernetes itself | rule `pod-security-restricted`, namespace labels |
| Admission | The database's service account and label reserved to the database image | rule `database-identity` |
| Admission | Services ClusterIP only, no external IPs; no NodePort or LoadBalancer by quota | rule `services`, quota |
| Admission | HTTPRoutes on `<app>-<team>.arffornia.com` only | rule `route-hostnames` |
| Admission | VaultSecrets only with the app's role | rule `vault-role` |
| Resources | Quota and default limits per app | `charts/gitlab-team/values.yaml` |

Admission rules hold for every object in the namespace, whoever creates it: they back up the
chart and the Argo CD project, they do not rely on them.

## Network

Network policies only restrict the pods they select. These select every pod of the app's
namespace, so the isolation holds without a cluster-wide default deny.

| From \ To | Same app | Same team, other app | Database of another app | Other team | LAN, Vault, cluster services | Internet |
|---|---|---|---|---|---|---|
| App pod | yes | yes | no | no | no | 80 and 443 |
| Gateway | yes, through HTTPRoutes | | | | | |

The database also reaches the Kubernetes API, for Patroni's leader election. Only the database
image may carry the label that opens it. Files: `charts/gitlab-team/templates/network.yaml`.

## Secrets

None is stored in a repository, and none is readable by a team member.

| Secret | Where it lives | Who can use it |
|---|---|---|
| Signing key | Vault transit `apps-<team>-<app>`, not exportable | A pipeline on `main` of the app, 5 minutes per login |
| `DEPLOY_REPO_TOKEN` | GitLab group variable, protected and hidden, rotated yearly by Terraform | `main` pipelines of the app. Leaked, it only lets someone write values: unsigned images are refused anyway |
| Registry pull | Group deploy token `read_registry`, Vault `kvv2/gitlab-agents/<team>-registry` | Kubelet and Kyverno, for that team's images |
| Deploy repositories read | Group deploy token `read_repository`, Vault `kvv2/gitlab-agents/<team>-repo` | Argo CD |
| Registry push | `CI_JOB_TOKEN`, valid for one job | The job |
| App secrets | Vault `kvv2/apps/<team>/<app>` | The app's namespace |
| Database credentials | Written by the postgres-operator in the app's namespace | The app |
| Keycloak client | None: public client with PKCE | |
| Agent token | Vault `kvv2/gitlab-agents/<team>` | The agent, which has no rights in the app namespaces |

## Attacks, and what stops them

| An attacker who | Tries to | Is stopped by |
|---|---|---|
| Is a Developer | Push an image with the release tag | Deployments use a signed digest, not a tag |
| Is a Developer | Change `.gitlab-ci.yml` in a branch to sign or deploy | Vault only signs for `ref=main`, protected; the token is protected |
| Is a Maintainer | Deploy a privileged pod, another image, a NodePort, another host | Schema, Argo CD project, Kyverno, quota |
| Is a Maintainer | Give a pod the database's identity to reach the API and create Services | Rule `database-identity` |
| Is a Maintainer | Alias an internal service through an ExternalName Service behind the gateway | Rule `services` |
| Is a Maintainer of app A | Deploy into app B, even of the same team | Argo CD project per app, signing key per app |
| Steals `DEPLOY_REPO_TOKEN` | Deploy their own image | Signature check |
| Steals a GitLab admin token | Reach the cluster | No path: GitLab has no access to the cluster |
| Runs code in an app | Reach Vault, the LAN, other teams, other databases | Network policies |
| Runs code in a CI job | Reach Gitaly, Redis, the LAN | Jobs namespace network policy |

## What remains

| Risk | Why | Fix |
|---|---|---|
| One Maintainer alone ships to production | No mandatory approvals on Free | Ultimate: approval rules, Code Owners, protected environments |
| Any Keycloak user gets a GitLab account and runs jobs on the shared runner | OmniAuth auto-creates users | `blockAutoCreatedUsers`, `defaultCanCreateGroup: false` (separate PR) |
| A `main` pipeline signs whatever the code builds | That is the point of trusting `main` | Reviews; Ultimate pipeline execution policies to force jobs the team cannot remove |
| A Developer can push a crafted layer to the build cache, which the next `main` build reuses and signs | The cache is in the project's registry, where Developers may push. Kept: builds without it are too slow. It only reaches that Developer's own app, and the registry's logs show who pushed | A cache only `main` pipelines write, in a registry Developers cannot push to |
| Apps reach the whole internet on 443 | Exfiltration is possible | Cilium FQDN policies: each app declares its domains |
| Shared runner, shared nodes, shared kernel | One cluster | Protected runners for `main`, dedicated nodes, or a cluster per sensitivity level |
| Inside its namespace a team owns its app, its data, its database credentials | By design | |
| GitLab, Vault and Argo CD are the roots of trust | Whoever administers them controls everything | Few admins, audited |

## Why Argo CD and not the GitLab agent

With the agent, the pipeline deploys: it holds the right to change the cluster, so whoever
controls a pipeline on `main`, or GitLab itself, does too. With Argo CD, the cluster pulls and
checks; GitLab only proposes. It also corrects manual changes (`selfHeal`), and needs no paid tier
to isolate apps: an Argo CD project per app replaces the agent's impersonation, which is Premium.

What the agent still offers, kept connected but without rights:

| Use | Tier | Without the agent |
|---|---|---|
| Workspaces: development environments in the cluster | Premium | Coder, Devpod |
| Operational container scanning, in GitLab's vulnerability report | Ultimate | Trivy Operator, results in the cluster |
| Kubernetes dashboard in GitLab | Free | Argo CD's UI |
| Review apps per merge request | Free | ApplicationSet with the pull request generator |

The price: the deployment status lives in Argo CD, not in the pipeline. Sending it back to the
commit in GitLab (argocd-notifications) is on the list.

## Check it

```sh
# Argo CD may not deploy outside its namespace or other kinds
kubectl -n argocd get appproject app-demo-timetrack -o yaml

# An unsigned image of the app is refused (tag pushed by hand)
kubectl -n demo-timetrack run t --image=gitlab-registry.arffornia.com/apps/demo/timetrack/backend:<tag> --dry-run=server

# The agent has no rights in the app namespace
kubectl auth can-i create deployments -n demo-timetrack \
  --as=system:serviceaccount:gitlab-agent-demo:gitlab-agent-demo   # no
```
