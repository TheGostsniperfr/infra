# App platform: guide

An app is a backend (Quarkus) and a frontend (React), each in its own GitLab repository. Their
pipelines build and sign images; Argo CD deploys them. Example: Time Track,
https://timetrack-demo.arffornia.com, repositories in `apps/demo/timetrack`.

What protects what, for a review or a presentation: [`SECURITY.md`](SECURITY.md).

## User stories

| Who wants what | What they give | What happens |
|---|---|---|
| A team asks for an app | Name, team, database or not, who is `manager` and `member` | A platform admin adds it to `teams/<team>.yaml`, runs `terraform apply`, merges. See [Create an app](#create-an-app) |
| A developer starts coding | | Clones `backend` and `frontend`, works on a branch, opens an MR. Only the tests and the check of `deploy.yaml` run: a branch never deploys |
| A maintainer ships | Merges the MR to `main` | `build`, `sign`, `release`, then Argo CD deploys within a minute |
| The new version is broken | | [Roll back](#roll-back) |
| A developer changes replicas, memory, a variable | Edits `deploy.yaml` | Deployed with the next release. A value outside the limits fails the pipeline |
| A developer wants a page without sign-in | | In the code: `@PermitAll` on the Quarkus resource, and no redirect to the login on that page in the frontend |
| A developer needs an API key in the app | The key's name, in `secrets` of `deploy.yaml` | A platform admin stores the value in Vault, `kvv2/apps/<team>/<app>`. The app gets it as a variable |
| Two apps of the same team talk to each other | | `http://<component>.<team>-<other-app>.svc.cluster.local:<port>`. Another team's app: through its public URL only |
| A developer wants another image, Redis for example | | Refused: only the app's own images, signed by its `main`, run. Ask the platform |
| A manager gives someone access | Their Keycloak username | Today a PR on `roles` in `teams/<team>.yaml`, applied by an admin |
| A team deletes an app | | Remove it from `teams/<team>.yaml`. `terraform apply` deletes the GitLab group with its repositories, the Vault keys, the Keycloak client and the DNS name. The merge deletes the namespace and the database with its data |

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
   - Project `deploy`, without CI, and a project access token that may push to it.
   - CI variables on the group: `DEPLOY_REPO`, `VAULT_ADDR`, `VAULT_SIGN_ROLE`, `SIGNING_KEY`,
     none secret, and `DEPLOY_REPO_TOKEN`, protected and hidden.
2. **Vault** (`terraform/apps.tf`)
   - Transit key `apps-<team>-<app>`, which signs and is never exported. Its public key in
     `kvv2/gitlab-agents/<team>-<app>-cosign`.
   - JWT role `sign-<team>-<app>`: a GitLab id_token from `main` of `apps/<team>/<app>` may sign
     with that key, nothing else.
   - Kubernetes role `apps-<team>-<app>`: reads `kvv2/apps/<team>/<app>` and the team's pull token.
3. **Keycloak** (`terraform/apps.tf`)
   - Public client `<team>-<app>` with PKCE, redirect URI `https://<app>-<team>.arffornia.com/*`.
   - An audience mapper, so the backend accepts the token.
   - Client roles `member` and `manager`.
   - Groups `app-<team>-<app>-members` and `-managers` with these roles, and their users.
4. **Cloudflare** (`terraform/apps.tf`): a proxied CNAME `<app>-<team>`.
5. **Kubernetes** (Argo CD, `charts/gitlab-team`)
   - Namespace `<team>-<app>`: quota, LimitRange, network policies, Kyverno rules, registry pull
     secret, Postgres database.
   - Argo CD project `app-<team>-<app>`, and one Application per component.
   - In `kyverno`: the app's public key. In `argocd`: the team's read token for the deploy repositories.
6. **First deployment**: a push to `main` of each repository.

Once per team, not per app: group `apps/<team>`, its registry and repository deploy tokens, its
agent. See `README.md`.

## Deploy a change

Push or merge to `main`. The pipeline of the repository runs:

| Stage | What | Branches |
|---|---|---|
| `test` | Unit tests, the backend's against a real Postgres. `deploy-config` checks `deploy.yaml` against the platform chart | All |
| `build` | Builds the image with Kaniko, without privileges, with a layer cache in the registry, and pushes it to the GitLab registry | `main` |
| `sign` | Signs the image's digest with the app's key in Vault | `main` |
| `release` | Writes `deploy.yaml` and the digest to `deploy/<component>.yaml`. Shows up in Operate > Environments | `main` |

Argo CD then renders the platform chart (`charts/app` in the infra repo) with that file, and
deploys it into `<team>-<app>`. Before a Pod starts, Kyverno checks the image's signature.

`deploy.yaml` is the only deployment file in a repository. What it may set:

| Key | What |
|---|---|
| `port`, `replicas`, `resources` | Within bounds: 0 to 3 replicas, CPU and memory requests, a memory limit |
| `env` | Plain variables. `DB_*`, `OIDC_*` and `POD_NAMESPACE` are reserved |
| `secrets` | Names of variables read from Vault, `kvv2/apps/<team>/<app>` |
| `database`, `oidc` | Inject the database or the Keycloak client variables |
| `route.path` | Publish the component on `https://<app>-<team>.arffornia.com<path>` |
| `health` | Paths of the startup, readiness and liveness probes |

Anything else is refused: the schema (`charts/app/values.schema.json`) has no other key. Name,
namespace, host, image, security context, service account and volumes are set by the platform.

## Roll back

Either of:

- GitLab > the repository > Operate > Environments > `production` > on an older deployment,
  **Re-deploy**. That release job writes its own `deploy.yaml` and digest again.
- GitLab > `apps/<team>/<app>/deploy` > revert the release commit.

A backend rollback fails if a database migration happened since. Flyway refuses to start an old
version on a newer schema, so the new Pod never becomes ready and the old one keeps serving. Fix
forward instead, with a new commit.

## Where to look

| Question | Where |
|---|---|
| Did my pipeline work? | The repository > Build > Pipelines |
| Which version is released, and what was before? | `apps/<team>/<app>/deploy`, its commits. Or Operate > Environments |
| Is it deployed and healthy? | Argo CD, applications `<team>-<app>-<component>`. Platform admins only for now |
| Why was it refused? | Argo CD, the sync error of the application: schema, Argo CD project or Kyverno |
| My images | The repository > Deploy > Container registry |
| Who may sign in, with which role | `roles` in `teams/<team>.yaml` |
| The pods, their logs | Platform admins: `kubectl -n <team>-<app>` or Argo CD |

## What the platform does

| Today | Later | Decided against, and why |
|---|---|---|
| An app from one YAML entry: repositories, namespace, database, SSO, DNS, signing key | Self-service, without a PR and an admin's `terraform apply` | Deploying from the pipeline through the GitLab agent: the pipeline would hold the right to deploy. See `SECURITY.md` |
| Tests, build, signature and release on every merge to `main`, deployment by Argo CD | One shared pipeline as a CI/CD component, so a fix reaches every app. Today a fork does not follow its template | Docker-in-Docker or a privileged BuildKit: a build could take over its node. Kaniko builds without privileges |
| A platform chart: teams choose values, never manifests | Argo CD access for each team to its own apps, and the deployment status on the commit in GitLab | |
| Rollback by Re-deploy in GitLab or by revert in `deploy` | Teams writing their own secrets in Vault | Backups of the apps' databases: it is a lab. Argo CD recreates a lost database, empty |
| Sign-in with Keycloak, roles `member` and `manager` checked by the backend | Managers adding users themselves | High availability: one pod per component and one database instance, nothing here needs to stay up |
| Teams and apps isolated, see `SECURITY.md` | Base images kept up to date by Renovate on the templates. A `preprod` environment | |
| | Logs and metrics of an app visible to its team. Backups of the Git repositories, email from GitLab | |
