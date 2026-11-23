# App platform: handbook

For the platform team: how to change the platform without opening a hole. Developers read
[`GUIDE.md`](GUIDE.md); the security model and its exceptions are in [`SECURITY.md`](SECURITY.md);
the layout and first install in [`README.md`](README.md).

## The rule behind every recipe

Everything is denied unless something allows it: the Argo CD project lists the kinds, the chart
schema lists the keys, Kyverno lists the images, the network policies list the flows. A change
either stays inside these lists, or adds to one of them. Adding is an **exception**: before
merging, answer these four questions in the PR, and add a line to the
[register of exceptions](SECURITY.md#register-of-exceptions):

1. What new right does it give: a kind, a key, an image, a flow, a Vault path, a GitLab permission?
2. To whom: every app, one app, one pipeline, one operator?
3. What contains it: which rule stops it from being used for something else?
4. How is it tested: the dry-run or the request that shows it is refused where it should be?

Test admission changes in a scratch namespace before the PR: copy the rendered Policy, apply it
there, `kubectl apply --dry-run=server` what must pass and what must not, delete the namespace.
Never test by editing what Argo CD manages: selfHeal reverts it.

## Add a team

1. `teams/<team>.yaml`, copied from `teams/demo.yaml`, in a PR.
2. `terraform apply` on the PR: GitLab group, agent, deploy tokens, share of `apps/platform/ci`.
3. Merge: Application `team-<team>`.
4. People sign in once, then an admin approves them (Admin > Users > Pending approval) and adds
   them to `apps/<team>`: Developer, or Maintainer for those who may ship.

## Add an app

[`GUIDE.md`, Create an app](GUIDE.md#create-an-app): an entry under `apps`, `terraform apply`,
merge, a push to `main` of each repository.

## Remove an app or a team

Remove the entry or the file, `terraform apply`, merge. The app's namespace and Argo CD project
are pruned with the team's Application; the database goes with its namespace. Removing a whole
team file keeps its resources (`preserveResourcesOnDeletion` on the ApplicationSet): delete its
namespaces by hand once nothing needs them.

## Offer a new service to the apps, Redis for example

The app chooses it with a key in `deploy.yaml` or in `teams/<team>.yaml`; the platform renders
it. Never let a team write the manifests.

| Step | Where |
|---|---|
| Install the operator, pinned, with its own Argo CD Application | `k8s/apps/`, `k8s/config/<operator>/` |
| Decide where the switch lives: per app and set by the platform (`database: true` in the team file) or chosen by the team (`deploy.yaml`) | |
| Render the custom resource | `charts/platform-team/templates/apps.yaml` for a platform switch, `charts/app` for a team one, with its key in `values.schema.json` |
| Allow the new kind in the app's Argo CD project, only if `charts/app` renders it | `charts/platform-team/templates/argocd.yaml` |
| The operator's image: allow it in the `images` rule; exempt it from `restricted` only if it cannot run without, and only the controls it needs | `charts/platform-team/templates/guardrails.yaml` |
| Its pods' identity: if they get a service account with rights or a label that opens a flow, reserve both to that image, as `database-identity` does | `guardrails.yaml` |
| Flows: the app to the service inside the namespace is already open; anything else, a policy per flow | `charts/platform-team/templates/network.yaml` |
| Its credentials: in the app's namespace, written by the operator, or in Vault under `kvv2/apps/<team>/<app>` | |
| Document it: the key in `GUIDE.md`, the exception in `SECURITY.md` | |

## Add a template, a Go worker for example

1. A project in `apps/platform/templates`: add it to `local.gitlab_templates` in
   `terraform/apps.tf`, `terraform apply`, push the code: `Dockerfile`, non-root, read-only root
   filesystem friendly; `deploy.yaml`; `.gitlab-ci.yml` with its own `test` job and the `release`
   component.
2. Add the component name to `components` in `charts/platform-team/values.yaml`: every app gets an
   Application for it, empty until its first release. Its images land in
   `<registry>/apps/<team>/<app>/<component>`, already allowed and signed with the app's key.
3. If it needs something `charts/app` cannot express, a CronJob for example: extend `charts/app`
   and its schema, and the Argo CD project's kinds. Then it is a new service, see above.

New templates only reach new apps: a fork does not follow its template. Existing apps that want
it get a new component by hand: a project in their group, forked from the template.

## A team needs something the platform does not do

In order of preference:

1. **It fits a key that exists**: an env var, a secret, a route path. Show them `GUIDE.md`.
2. **Several teams will want it**: make it a platform feature, a key in the schema or a service
   above. Everyone gets it, tested once.
3. **Only this team, and it is worth it**: an exception, decided by the platform team, written in
   the register with an owner and a review date. Implement it as narrowly as possible: one
   namespace, one image, one flow.
4. **It does not belong on this platform**: a privileged workload, a node-level agent, a
   database the team administers itself. Say no, and say where it should run instead.

Never give a team rights in its namespace to "unblock" it: every guarantee in `SECURITY.md` rests
on teams having none.

## Change the shared CI

`apps/platform/ci`, component `release`. Change `templates/release.yml`, merge, tag a new
version, then bump the version in the templates and the apps. A change that needs new group
variables or stages is a new major version. Teams can still edit their `.gitlab-ci.yml`; what
matters stays enforced elsewhere: Vault only signs for `main`, Kyverno only admits signed images.

## Change a security rule

| Rule | File | Test before merge |
|---|---|---|
| Kyverno rules of the app namespaces | `charts/platform-team/templates/guardrails.yaml` | Scratch namespace dry-runs: what must pass, what must not. Include the database StatefulSet: `kubectl get sts <app>-db -o json`, change the namespace, dry-run it |
| Network policies | `charts/platform-team/templates/network.yaml` | `kubectl exec` into a pod of the app, `wget -T 5` to what must and must not answer |
| Argo CD project | `charts/platform-team/templates/argocd.yaml` | Sync of every app after merge: a missing kind fails the sync |
| Chart schema | `charts/app/values.schema.json` | `helm template` with a value that must be refused; the apps' `deploy-config` job runs it on every push |
| Vault roles and policies | `terraform/apps.tf` | `terraform plan`, then a pipeline on `main` (sign) and on a branch (must not sign) |

## Rotate the signing key of an app

Kyverno trusts one public key per app: rotating breaks every running image until it is signed
again.

1. Rotate: `vault write -f transit/keys/apps-<team>-<app>/rotate`. It is an operation Terraform
   cannot express, not a configuration: the key's settings stay in Terraform.
2. `terraform apply`: it reads the new version and writes its public key to
   `kvv2/gitlab-agents/<team>-<app>-cosign`; the VaultSecret in `kyverno` follows.
3. Release each component again (a push to `main`, or re-run its last pipeline): new signatures
   use the new version.
4. Between 2 and 3, a pod restarting on an old image is refused. Running pods are not checked
   again. For no window at all, list both public keys in the rule `signed-images` during the
   change.

## Revoke a token

| Token | How |
|---|---|
| `DEPLOY_REPO_TOKEN` | `terraform apply -replace=gitlab_project_access_token.app_deploy["<team>/<app>"]` |
| Registry and repository deploy tokens | `-replace=` the `gitlab_group_deploy_token`; the VaultSecrets pick the new one up |
| Agent token | `-replace=gitlab_cluster_agent_token.team["<team>"]` |
| A person | Block them in GitLab (Admin > Users) and disable them in Keycloak |

## An app is compromised

1. Cut it off: `replicas: 0` in its deploy repository, or delete its HTTPRoute (Argo CD will put
   it back: pause the Application's auto-sync first, in the UI).
2. Keep the evidence: the image digest, the deploy repository's history, the pipeline that signed
   it, the pod logs before they go.
3. Revoke what it could reach: its secrets in Vault, its database password (delete the operator's
   Secret, it creates a new one), the tokens of whoever pushed.
4. Fix forward with a new release from `main`, then resume auto-sync.

What it could not reach, and so does not need checking: Vault, other teams, other databases,
the LAN, the Kubernetes API (`SECURITY.md`, Network).
