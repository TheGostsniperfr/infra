# App platform: teams and Argo CD

A team is a GitLab group `apps/<team>`: its members, and one subgroup per application. Its apps
are deployed by Argo CD from their `deploy` repositories (`charts/platform-team`, `charts/app`).
There is no GitLab agent for Kubernetes: no pipeline reaches the cluster, Argo CD pulls. Why:
[`SECURITY.md`](SECURITY.md).

To create and deploy an app, read [`GUIDE.md`](GUIDE.md). To change the platform: [`HANDBOOK.md`](HANDBOOK.md).

## How a deployment reaches the cluster

1. A pipeline on `main` signs its image with the app's key in Vault and writes
   `deploy/<component>.yaml` (values and digest).
2. Argo CD, Application `<team>-<app>` in project `app-<team>-<app>`, reads it with the team's
   `read_repository` token and renders `charts/app` once per component, plus `charts/app-database`.
   The values the platform sets (`platform.*`) take precedence over the file. That one Application
   shows the whole app: workloads, their Pods and logs, the database and its Pods.
3. Kyverno admits the Pods if the image is the app's and its signature checks out against the
   public key in `kyverno/cosign-<team>-<app>`.

## Isolation model: one Argo CD project per app

GitLab's answer to multi-tenancy is one agent with *impersonation*, Premium. On Free a job using
an agent has all of the agent's rights, hence one agent per team when the agents deployed (until
2026-11-10; the agents were removed on 2026-11-23). Argo CD projects are free and per app:
destination namespace, allowed kinds, source repositories.

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
| `../../../architecture/app-platform` | noodle diagrams, renders in `architecture/diagrams/app-platform-*`: see [Diagrams](#diagrams) |
| `teams/<team>.yaml` | The team: display name and application namespaces. The only file to add per team |
| `../../../charts/platform-team` | Per team: app namespaces, network policies, Kyverno rules, Argo CD projects and Applications |
| `../../../charts/app` | The platform chart of one component, with the schema of what a team may set |
| `../../apps/app-platform-teams.yaml` | ApplicationSet `app-platform-teams`: one Application `team-<team>` per file in `teams/` |
| `../../../terraform/gitlab.tf` | Per file in `teams/`: GitLab group `apps/<team>` |
| `../../../terraform/apps.tf` | Per app: repositories, deploy token, signing key and Vault roles, Keycloak client, DNS |

## Diagrams

Start with `overview`, then follow an app through `onboarding` and `release`.

| View | Question |
|---|---|
| [overview](../../../architecture/diagrams/app-platform-overview.light.png) | Which repository, GitLab project and namespace hold each piece, and what reads what |
| [onboarding](../../../architecture/diagrams/app-platform-onboarding.light.png) | What happens between a ticket and an app ready for its first push |
| [release](../../../architecture/diagrams/app-platform-release.light.png) | What happens between a merge to main and the new pod, and who checks what |
| [delivery](../../../architecture/diagrams/app-platform-delivery.light.png) | The same release as a topology: what can refuse it on the way |
| [isolation](../../../architecture/diagrams/app-platform-isolation.light.png) | What a pod of an app can reach |

## Add a team

1. Add `teams/<team>.yaml` (copy `teams/demo.yaml`) in a PR.
2. `terraform apply` on the PR: group `apps/<team>`, the team's deploy tokens, and per app its
   projects, keys and roles.
3. Merge: the ApplicationSet creates `team-<team>`: per app its namespace, Argo CD project and
   Applications.
4. Once each of the team's people has signed in, approve them (Admin > Users > Pending approval)
   and add them to `apps/<team>` only, never to `apps` or `apps/platform`.

## Check the isolation

```sh
kubectl -n argocd get appproject app-demo-timetrack -o jsonpath='{.spec.destinations}'
kubectl -n demo-timetrack get policy app-guardrails -o jsonpath='{.spec.rules[*].name}'
```

## First install

1. Create a personal access token for `root` (Admin > Users > root > Impersonation tokens, or
   root's own Access tokens), scope `api`, with an expiry date. Add it to the sops tfvars as
   `gitlab_admin_token_var`.
2. `terraform init` (new provider `gitlabhq/gitlab`), `terraform plan`, `terraform apply`.
3. Merge: the ApplicationSet creates one Application `team-<team>` per team file.
