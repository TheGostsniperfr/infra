# App platform: teams, agents and Argo CD

A team is a GitLab group `apps/<team>`: its members, and one subgroup per application. Its apps
are deployed by Argo CD from their `deploy` repositories (`charts/platform-team`, `charts/app`).
Each team also gets a GitLab agent (`agentk`), connected but without CI access or rights in the
app namespaces: it is kept for what only it can do. Why: [`SECURITY.md`](SECURITY.md).

To create and deploy an app, read [`GUIDE.md`](GUIDE.md). To change the platform: [`HANDBOOK.md`](HANDBOOK.md).

## How a deployment reaches the cluster

1. A pipeline on `main` signs its image with the app's key in Vault and writes
   `deploy/<component>.yaml` (values and digest).
2. Argo CD, Application `<team>-<app>-<component>` in project `app-<team>-<app>`, reads it with the
   team's `read_repository` token and renders `charts/app`. The values the platform sets
   (`platform.*`) take precedence over the file.
3. Kyverno admits the Pods if the image is the app's and its signature checks out against the
   public key in `kyverno/cosign-<team>-<app>`.

The agent: `agentk` (namespace `gitlab-agent-<team>`) keeps a websocket open to KAS, in-cluster
(`ws://gitlab-kas.gitlab.svc.cluster.local:8150`). Its config, written by Terraform, is empty.

## Isolation model: one Argo CD project per app

GitLab's answer to multi-tenancy is one agent with *impersonation*, Premium. On Free a job using
an agent has all of the agent's rights, hence one agent per team when the agents deployed. Argo CD
projects are free and per app: destination namespace, allowed kinds, source repositories.

| | Agent + impersonation | Agent per team | Argo CD project per app (this setup) |
|---|---|---|---|
| Tier | Premium/Ultimate | Free | Free |
| Isolation unit | project, environment | team | app |
| Who holds the right to deploy | the pipeline | the pipeline | Argo CD, in the cluster |

- Argo CD projects: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
- Agent: https://docs.gitlab.com/user/clusters/agent/
- Impersonation: https://docs.gitlab.com/user/clusters/agent/ci_cd_workflow/#restrict-project-and-group-access-by-using-impersonation

## What is restricted, and where

The full list, with the secrets and the attacks: [`SECURITY.md`](SECURITY.md).

## Layout

| Path | What |
|---|---|
| `../../../architecture/app-platform` | noodle diagrams: views `delivery` and `isolation`, renders in `architecture/diagrams/app-platform-*` |
| `teams/<team>.yaml` | The team: display name and application namespaces. The only file to add per team |
| `agent-values.yaml` | Values of the official `gitlab-agent` chart, shared by every team |
| `../../../charts/platform-team` | Per team: agent namespace and token, app namespaces, network policies, Kyverno rules, Argo CD projects and Applications |
| `../../../charts/app` | The platform chart of one component, with the schema of what a team may set |
| `../../apps/app-platform-teams.yaml` | ApplicationSet `app-platform-teams`: one Application `team-<team>` per file in `teams/` |
| `../../../terraform/gitlab.tf` | Per file in `teams/`: GitLab group, agent project, agent, config, token in Vault |
| `../../../terraform/apps.tf` | Per app: repositories, deploy token, signing key and Vault roles, Keycloak client, DNS |

## Add a team

1. Add `teams/<team>.yaml` (copy `teams/demo.yaml`) in a PR.
2. `terraform apply` on the PR: group `apps/<team>`, project `apps/platform/agent-<team>`, the
   agent, its config and its token in `kvv2/gitlab-agents/<team>`, the team's deploy tokens.
3. Merge: the ApplicationSet creates `team-<team>`: the agent, and per app its namespace,
   Argo CD project and Applications.
4. Once each of the team's people has signed in, approve them (Admin > Users > Pending approval)
   and add them to `apps/<team>` only, never to `apps` or `apps/platform`.

## Check the isolation

```sh
kubectl auth can-i create deployments -n demo-timetrack \
  --as=system:serviceaccount:gitlab-agent-demo:gitlab-agent-demo   # no: the agent does not deploy
kubectl -n argocd get appproject app-demo-timetrack -o jsonpath='{.spec.destinations}'
kubectl -n demo-timetrack get policy app-guardrails -o jsonpath='{.spec.rules[*].name}'
```

## First install

1. Create a personal access token for `root` (Admin > Users > root > Impersonation tokens, or
   root's own Access tokens), scope `api`, with an expiry date. Add it to the sops tfvars as
   `gitlab_admin_token_var`.
2. `terraform init` (new provider `gitlabhq/gitlab`), `terraform plan`, `terraform apply`.
3. Merge: Argo CD deploys the agent, the VaultSecret pulls its token, the agent connects.
   Check in GitLab: `apps/platform/agent-demo` > Operate > Kubernetes clusters shows the agent connected.
