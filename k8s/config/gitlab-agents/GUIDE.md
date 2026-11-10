# App platform: guide

An app is a backend (Quarkus) and a frontend (React), each in its own GitLab repository, deployed
to Kubernetes by their pipelines. Example: Time Track, https://timetrack-demo.arffornia.com,
repositories in `apps/demo/timetrack`.

## Create an app

1. In `teams/<team>.yaml`, add the app under `apps` and say who gets which role:
   ```yaml
   apps:
     timetrack:
       database: true        # a Postgres database, timetrack-db
       roles:
         manager: [brian]    # Keycloak usernames
         member: [brian]
   ```
2. Open a PR. A platform admin runs `terraform apply`, then merges.

You get:

| What | Where |
|---|---|
| Group with the repositories `backend` and `frontend`, forked from the templates | `apps/<team>/<app>` in GitLab |
| Namespace, database, quota | `<team>-<app>` in Kubernetes |
| Public URL | `https://<app>-<team>.arffornia.com` |
| Sign-in with roles `member` and `manager` | Keycloak client `<team>-<app>`, groups `app-<team>-<app>-members` and `-managers` |

## Deploy a change

Push to `main`. The pipeline of the repository runs:

| Stage | What |
|---|---|
| `test` | Unit tests. The backend's run against a real Postgres. Runs on every branch |
| `build` | Builds the image with Kaniko and pushes it to the GitLab registry, tagged with the commit |
| `deploy` | `helm upgrade` through the team's agent. If the new version does not become ready within 5 minutes, Helm puts back the previous one |

Other branches only run `test`. Merge them to `main` to deploy.

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

## What the platform does

| Today | Later | Decided against, and why |
|---|---|---|
| An app from one YAML entry: repositories, namespace, database, SSO, DNS | Self-service, without a PR and an admin's `terraform apply` | Custom project templates: Premium. Apps are forks of `apps/platform/templates/*` |
| Tests, build and deploy on every push to `main` | A `preprod` environment. The agents already accept the `preprod` branch | Docker-in-Docker or a privileged BuildKit: a build could take over its node. Kaniko builds without privileges |
| Automatic rollback of a failed deployment, manual rollback from Environments | Template changes reaching the existing apps. A fork does not follow its template | One shared agent with impersonation: Premium. One agent per team instead, see `README.md` |
| Sign-in with Keycloak, roles `member` and `manager` checked by the backend | Logs and metrics of an app visible to its team | Backups of the apps' databases: it is a lab. Argo CD recreates a lost database, empty |
| Teams isolated: one agent per team, namespaces, quotas, network policies, CI jobs without access to the LAN | Backups of the Git repositories (Gitaly) | High availability: one pod per component and one database instance, nothing here needs to stay up |
| | Email from GitLab (SMTP) | |
