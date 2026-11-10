# App platform: guide

An app is a backend (Quarkus) and a frontend (React), each in its own GitLab repository, deployed
to Kubernetes by their pipelines. Example: Time Track, https://timetrack-demo.arffornia.com,
repositories in `apps/demo/timetrack`.

## User stories

| Who wants what | What they give | What happens |
|---|---|---|
| A team asks for an app | Name, team, database or not, who is `manager` and `member` | A platform admin adds it to `teams/<team>.yaml`, runs `terraform apply`, merges. See [Create an app](#create-an-app) |
| A developer starts coding | | Clones `backend` and `frontend`, works on a branch, opens an MR. Only `test` runs: no deployment from a branch |
| A maintainer ships | Merges the MR to `main` | `test`, `build`, `deploy`. The site has the new version within minutes |
| The new version is broken | | If it never becomes ready, Helm puts the previous one back by itself. Otherwise: [Roll back](#roll-back) |
| A manager gives someone access | Their Keycloak username | Today a PR on `roles` in `teams/<team>.yaml`, applied by an admin |
| A developer wants a page without sign-in | | In the code: `@PermitAll` on the Quarkus resource, and no redirect to the login on that page in the frontend |
| A developer needs an API key in the app | | Not covered yet: ask a platform admin. See [What the platform does](#what-the-platform-does) |
| A developer wants another image, Redis for example | | Refused: only the app's own images run. Build it in the app's pipeline or ask the platform |
| A team deletes an app | | Remove it from `teams/<team>.yaml`. `terraform apply` deletes the GitLab group with its repositories, the Keycloak client and the DNS name. The merge deletes the namespace and the database with its data |

People in a team's GitLab group: **Developer** to code and open MRs, **Maintainer** to merge to
`main` and so to deploy. Only Maintainers may push or merge to `main`.

## Create an app

The YAML entry, then `terraform apply`:

```yaml
# teams/<team>.yaml
apps:
  timetrack:
    database: true        # a Postgres database, timetrack-db
    roles:
      manager: [brian]    # Keycloak usernames
      member: [brian]
```

What that does, system by system, as it would be done by hand:

1. **GitLab** (`terraform/apps.tf`)
   - Group `apps/<team>/<app>`.
   - Fork `apps/platform/templates/quarkus-backend` and `react-frontend` into it, as `backend` and `frontend`.
   - 7 CI variables on the group: `KUBE_CONTEXT`, `APP_NAMESPACE`, `APP_HOST`, `DB_HOST`,
     `DB_SECRET`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`. None is a secret.
2. **Keycloak** (`terraform/apps.tf`)
   - Public client `<team>-<app>` with PKCE, redirect URI `https://<app>-<team>.arffornia.com/*`.
   - An audience mapper, so the backend accepts the token.
   - Client roles `member` and `manager`.
   - Groups `app-<team>-<app>-members` and `-managers` with these roles, and their users.
3. **Cloudflare** (`terraform/apps.tf`): a proxied CNAME `<app>-<team>`.
4. **Kubernetes** (Argo CD, `charts/gitlab-team`): namespace `<team>-<app>`, the agent's Role,
   quota, LimitRange, network policies, admission rules, registry pull secret, Postgres database.
5. **First deployment**: a push to `main` of each repository.

Once per team, not per app: group `apps/<team>`, its agent in `apps/platform/agent-<team>`, its
registry deploy token. See `README.md`.

## Deploy a change

Push or merge to `main`. The pipeline of the repository runs:

| Stage | What |
|---|---|
| `test` | Unit tests. The backend's run against a real Postgres. Runs on every branch |
| `build` | Builds the image with Kaniko and pushes it to the GitLab registry, tagged with the commit |
| `deploy` | `helm upgrade` through the team's agent. If the new version does not become ready within 5 minutes, Helm puts back the previous one |

The `chart/` of each repository is the app's own deployment. Its empty values (`image`, `host`,
`oidc`...) are filled by the `deploy` job with `--set`, from the group's CI variables. A developer
may change the chart: the limits below are enforced by the cluster, not by the chart.

## Roll back

GitLab > the repository > Operate > Environments > `production` > on an older deployment, **Re-deploy**.
It runs that deployment's job again, with its image.

A backend rollback fails if a database migration happened since. Flyway refuses to start an old
version on a newer schema, and Helm keeps the current version. Fix forward instead, with a new commit.

## Where to look

| Question | Where |
|---|---|
| Did my deployment work? | The repository > Build > Pipelines |
| Which version runs, and what ran before? | The repository > Operate > Environments |
| My images | The repository > Deploy > Container registry |
| Who may sign in, with which role | `roles` in `teams/<team>.yaml` |
| The pods, their logs | Platform admins: `kubectl -n <team>-<app>` |

## Secrets and isolation

**Secrets**: none is stored in GitLab, and none is readable by a team member.

| Secret | Where it lives | Who can read it |
|---|---|---|
| Agent token | Vault `kvv2/gitlab-agents/<team>`, synced to the agent's namespace | The agent. The agent project is in `apps/platform`, which teams are not members of |
| Kubernetes access of a job | None: GitLab injects a context per job, which goes through the agent | Only jobs on a protected branch, so only what a Maintainer merged |
| Registry pull | Group deploy token `read_registry`, Vault `kvv2/gitlab-agents/<team>-registry` | The app namespaces of that team |
| Registry push | `CI_JOB_TOKEN`, valid for one job | The job |
| Database credentials | Written by the postgres-operator in the app's namespace | The app, and the team's pipelines |
| Keycloak client | None: the client is public, with PKCE | |

**Isolation**: what a team's pipeline cannot do, and what stops it.

| A pipeline cannot | Enforced by |
|---|---|
| Use another team's agent, or its own from a branch other than `main` | Agent config `ci_access` and `protected_branches_only`, written by Terraform |
| Change its agent's config or create a token for it | Agent project in `apps/platform`, admins only |
| Touch another namespace, or anything cluster-wide | Role `app-deployer`, only in the team's app namespaces |
| Change its quota, network policies, admission rules, RBAC, database settings | Not in `app-deployer`. Argo CD puts them back anyway |
| Run a privileged pod, as root, with host access | Pod Security `baseline` by Kubernetes, `restricted` by Kyverno. Only the database image is exempted from 4 controls |
| Run an image other than its app's | Kyverno: `gitlab-registry.arffornia.com/apps/<team>/<app>/` and the database image only |
| Publish another hostname, `auth.arffornia.com` for example | Kyverno: HTTPRoutes may only use `<app>-<team>.arffornia.com` |
| Reach the LAN, Vault, other databases | Egress policy: DNS, its namespace, ports 80 and 443 outside private ranges |
| Open a LoadBalancer or NodePort | Quota at 0 |
| Starve the cluster | Quota and LimitRange |
| Reach the LAN from a CI job | Jobs run in `gitlab-ci-jobs`, internet only |

What remains: inside its own namespace a team has full rights on its app, its data and its
database credentials. And whoever can merge to `main` deploys.

## What the platform does

| Today | Later | Decided against, and why |
|---|---|---|
| An app from one YAML entry: repositories, namespace, database, SSO, DNS | Self-service, without a PR and an admin's `terraform apply` | Custom project templates: Premium. Apps are forks of `apps/platform/templates/*` |
| Tests, build and deploy on every merge to `main` | One shared pipeline as a CI/CD component, so a fix reaches every app. Today a fork does not follow its template | Docker-in-Docker or a privileged BuildKit: a build could take over its node. Kaniko builds without privileges |
| Automatic rollback of a failed deployment, manual rollback from Environments | Base images kept up to date by Renovate on the templates | One shared agent with impersonation: Premium. One agent per team instead, see `README.md` |
| Sign-in with Keycloak, roles `member` and `manager` checked by the backend | Managers adding users themselves | Backups of the apps' databases: it is a lab. Argo CD recreates a lost database, empty |
| Teams isolated, see [Secrets and isolation](#secrets-and-isolation) | Secrets for the app itself, an API key for example, from Vault | High availability: one pod per component and one database instance, nothing here needs to stay up |
| | A `preprod` environment. The agents already accept the `preprod` branch | |
| | Logs and metrics of an app visible to its team | |
| | Backups of the Git repositories (Gitaly), email from GitLab (SMTP) | |
