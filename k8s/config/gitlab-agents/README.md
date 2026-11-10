# GitLab agents for Kubernetes

A team is a GitLab group `apps/<team>`: its members, and one project per application. Each team
that deploys applications from GitLab gets its own agent (`agentk`). The agent opens an
outbound tunnel to KAS (in namespace `gitlab`); GitLab CI jobs of the team then run `kubectl` or
`helm` against this cluster through that tunnel, without any kubeconfig or cluster credential in
GitLab.

## How a deployment reaches the cluster

1. `agentk` (namespace `gitlab-agent-<team>`) keeps a websocket open to KAS, in-cluster
   (`ws://gitlab-kas.gitlab.svc.cluster.local:8150`).
2. A CI job of a project in `apps/<team>` gets a Kubernetes context named
   `apps/platform/agent-<team>:<team>` (`KUBECONFIG` is injected by GitLab).
3. Its `kubectl` calls go to KAS (`https://gitlab-kas.arffornia.com/k8s-proxy`), which relays them
   through the tunnel; `agentk` sends them to the API server **with its own service account**.
4. That service account only has `edit` in the team's namespaces (`charts/gitlab-team`), so the
   job can do nothing else.

## Isolation model: one agent per team

GitLab recommends one agent per cluster and *impersonation* for multi-tenancy: each CI job is
then seen as `gitlab:project:<id>`, `gitlab:group:<id>` and RBAC is written per project. Impersonation
is Premium/Ultimate. On the free tier a CI job "inherits all the permissions from the service
account used to install the agent", so two teams sharing an agent would share all their rights.
Hence one agent per team, each with a service account limited to that team's namespaces.

| | One agent + impersonation | One agent per team (this setup) |
|---|---|---|
| Tier | Premium/Ultimate | Free |
| Isolation unit | project, group, environment | team (all its projects share the rights) |
| Cost | one Deployment | one Deployment and one GitLab project per team |

Moving to impersonation later means: one agent, `access_as: {ci_job: {}}` in its config, and
RoleBindings to the groups `gitlab:project:<id>` instead of to the agents' service accounts.

- Feature: https://docs.gitlab.com/user/clusters/agent/
- Multiple agents: https://docs.gitlab.com/user/clusters/agent/install/#install-multiple-agents-in-your-cluster
- Impersonation: https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/#restrict-project-and-group-access-by-using-impersonation

## What is restricted, and where

| Rule | Where |
|---|---|
| Only projects of group `apps/<team>` may use the agent | `ci_access.groups` in the agent config, written by `terraform/gitlab.tf` |
| The team cannot change its agent's config or create a token for it | the agent project is `apps/platform/agent-<team>`, outside the team's group; only platform admins are members of `apps` and `apps/platform` |
| Only pipelines on protected branches (`main`, `preprod`) may use it | `protected_branches_only: true`, same place |
| The agent can only touch its team's namespaces | `rbac.create: false` in `agent-values.yaml`, RoleBindings in `charts/gitlab-team` |
| No cluster-wide right at all | operational container scanning (Ultimate) disabled: it grants a ClusterRole that reads every Secret |
| A team cannot starve the cluster, no LoadBalancer | `ResourceQuota` and `LimitRange` per namespace |

The agent config lives in GitLab (`apps/platform/agent-<team>`, `.gitlab/agents/<team>/config.yaml`),
because KAS only reads it there, but it is written by Terraform: change it in `terraform/gitlab.tf`,
never in GitLab. It only lists who may use the agent; the agent's rights in the cluster are the
RBAC of `charts/gitlab-team`, which GitLab users cannot see or change.

- CI access: https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/#authorize-projects-in-your-groups-to-access-the-agent
- Protected branches: https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/#restrict-access-to-the-agent-to-protected-branches
- Helm RBAC: https://docs.gitlab.com/user/clusters/agent/install/#customize-the-helm-installation

## Layout

| Path | What |
|---|---|
| `teams/<team>.yaml` | The team: display name and application namespaces. The only file to add per team |
| `agent-values.yaml` | Values of the official `gitlab-agent` chart, shared by every team |
| `../../../charts/gitlab-team` | Per team: agent namespace and token, application namespaces, RBAC, quota |
| `../../apps/gitlab-agents.yaml` | ApplicationSet: one Application `gitlab-agent-<team>` per file in `teams/` |
| `../../../terraform/gitlab.tf` | Per file in `teams/`: GitLab group, agent project, agent, config, token in Vault |

## Add a team

1. Add `teams/<team>.yaml` (copy `teams/demo.yaml`) in a PR.
2. `terraform apply` on the PR: group `apps/<team>`, project `apps/platform/agent-<team>`, the
   agent, its config and its token in `kvv2/gitlab-agents/<team>`.
3. Merge: the ApplicationSet creates `gitlab-agent-<team>`, the agent connects.
4. Add the team's people to `apps/<team>` only, never to `apps` or `apps/platform`.

## Check the isolation

```sh
SA=system:serviceaccount:gitlab-agent-demo:gitlab-agent-demo
kubectl auth can-i create deployments -n demo-sandbox --as=$SA   # yes
kubectl auth can-i get secrets -n gitlab --as=$SA                # no
kubectl auth can-i list namespaces --as=$SA                      # no
```

## First install

1. Create a personal access token for `root` (Admin > Users > root > Impersonation tokens, or
   root's own Access tokens), scope `api`, with an expiry date. Add it to the sops tfvars as
   `gitlab_admin_token_var`.
2. `terraform init` (new provider `gitlabhq/gitlab`), `terraform plan`, `terraform apply`.
3. Merge: Argo CD deploys the agent, the VaultSecret pulls its token, the agent connects.
   Check in GitLab: `apps/platform/agent-demo` > Operate > Kubernetes clusters shows the agent connected.
