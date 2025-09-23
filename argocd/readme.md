# Argo CD (Hands‑on, Command‑first)

## 0) Prerequisites

**You need:** a Kubernetes cluster (and `kubectl`), plus permissions to create namespaces/CRDs; we’ll install Argo CD and use the official CLI.



## 1) Install Argo CD (Day‑0 bootstrap)

**Create the control‑plane namespace and install the official manifests.**
These install the API server, repo‑server, application controller, CRDs, etc.

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> Tip: For local/dev access without Ingress/LB, port‑forward the API server.

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# UI/API at https://localhost:8080
```

**Get the initial admin password (printed by the CLI).**

```bash
argocd admin initial-password -n argocd
```

> After you change the admin password, **delete** the `argocd-initial-admin-secret` (it only stores the bootstrap password and will be re‑created if needed).



## 2) Install & Log in with the Argo CD CLI

**Install the CLI (choose your OS).**

```bash
# macOS (Homebrew)
brew install argocd

# Linux (binary)
VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"
chmod +x argocd && sudo mv argocd /usr/local/bin/
```

**Log in (basic/SSO) to your server or the forwarded localhost.**

```bash
# Username/password
argocd login <ARGOCD_SERVER>

# Single Sign-On (if configured)
argocd login <ARGOCD_SERVER> --sso
```

> If Argo CD isn’t externally reachable, add `--port-forward-namespace argocd` to CLI commands or set `export ARGOCD_OPTS='--port-forward-namespace argocd'`.



## 3) First Sync — Your “Hello, GitOps” Application

**Register (optional) an external cluster** to deploy to; skip if deploying in‑cluster.

```bash
# See kubectl contexts, then add one:
kubectl config get-contexts -o name
argocd cluster add <KUBECONTEXT_NAME>
```

**Create a simple app from a Git repo** (directory/Kustomize/Helm supported).

```bash
# Example: directory app (guestbook)
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

**Inspect the app (status/diff) & deploy (sync).**

```bash
# Check current status and drift
argocd app get guestbook

# Show precise differences between desired vs live state
argocd app diff guestbook

# Reconcile to target state (create/update/delete as needed)
argocd app sync guestbook
```

**Wait until the app is healthy/synced (CI‑friendly).**

```bash
argocd app wait guestbook --health --sync
```

**See rollout logs and history (then roll back).**

```bash
# Pod logs of resources owned by the app
argocd app logs guestbook

# Deployment history and rollback
argocd app history guestbook
argocd app rollback guestbook             # roll back to previous
argocd app rollback guestbook <HISTORY_ID>
```



## 4) Add Repositories & Credentials (Git/Helm/OCI/SSH/HTTPS)

**Add a Git repo (HTTPS user/pass or SSH key).**

```bash
# HTTPS
argocd repo add https://github.com/your-org/your-repo.git \
  --username <USER> --password <TOKEN>

# SSH
argocd repo add git@github.com:your-org/your-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

**Add a Helm repo or an OCI‑based Helm registry.**

```bash
# Traditional Helm repository
argocd repo add https://argoproj.github.io/argo-helm --type helm

# OCI Helm registry (note: omit oci:// in the URL here)
argocd repo add registry-1.docker.io/bitnamicharts --type helm --enable-oci=true \
  --username <USER> --password <TOKEN>
```

**List repos or declare credential templates for many repos at once.** ([GitHub][1])

```bash
argocd repo list
argocd repocreds list
```

> Argo CD also supports **OCI as a first‑class source** in Application specs (e.g., `repoURL: oci://…`).



## 5) Create Applications (Directory, Kustomize, Helm, Helm\@repo, Multi‑source)

**Directory JSON/YAML:**

```bash
argocd app create mydir \
  --repo https://github.com/your-org/platform-apps.git \
  --path apps/mydir \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace platform
```

**Kustomize (with image override):**

```bash
argocd app create mykustomize \
  --repo https://github.com/your-org/platform-apps.git \
  --path kustomize/overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace platform \
  --kustomize-image your.registry/app:v1.2.3
```

**Helm (chart in Git):**

```bash
argocd app create myhelm-git \
  --repo https://github.com/your-org/platform-apps.git \
  --path helm/myservice \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace platform \
  --helm-set replicaCount=3
```

**Helm (chart from Helm or OCI repo):**

```bash
argocd app create nginx-ingress \
  --repo https://charts.helm.sh/stable \
  --helm-chart nginx-ingress \
  --revision 1.24.3 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ingress
```

**Multi‑source apps (compose Git + Helm + Kustomize):** use an Application YAML (CLI supports `--file`).

```bash
argocd app create composed --file ./applications/composed-app.yaml
```



## 6) Sync Operations — Fast, Safe, and Selective

**Manually sync an app (or many by label), including only specific resources.** ([Argo CD][2])

```bash
# Full app
argocd app sync my-app

# All children of an app-of-apps by label
argocd app sync -l app.kubernetes.io/instance=my-parent

# Only a specific resource (by group:kind:name)
argocd app sync my-app --resource apps:Deployment:api
```

**Selective Sync (sync only out‑of‑sync objects) to reduce API load.** ([Argo CD][3])

```bash
# One-time via CLI
argocd app sync my-app --apply-out-of-sync-only

# Persist as policy
argocd app set my-app --sync-option ApplyOutOfSyncOnly=true
```

**Automated sync with prune & self‑heal.**
(*Automated = Argo keeps the cluster in the desired state, prunes removed objects and self‑heals drift.*)

```bash
# Enable automation plus safety toggles
argocd app set my-app --sync-policy automated --auto-prune --self-heal
```

**Sync waves and hooks for ordered, orchestrated rollouts.**
(Annotate resources with `argocd.argoproj.io/sync-wave: "<int>"`, negative/positive, default wave 0.) ([Argo CD][4])

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"   # run before wave 0 resources
```



## 7) Projects, Multi‑Tenancy & RBAC (Enterprise Hardening)

**Create a Project and restrict sources/destinations (tenant guardrails).**

```bash
argocd proj create finops \
  --description "FinOps apps" \
  --dest https://kubernetes.default.svc,finops \
  --src https://github.com/your-org/finops-apps.git
```

**Add fine‑grained roles and issue scoped JWT tokens (for CI/CD or teams).**

```bash
# Create role and attach policy
argocd proj role create finops deployer --description "Deploy only"
argocd proj role add-policy finops deployer -a sync -p allow -o applications -r finops/*

# Mint a token for automations
argocd proj role create-token finops deployer -t
```

**Sync Windows** (allow/deny syncs by cron schedule) at project level.

```yaml
# In AppProject spec (YAML): block prod syncs during office hours
spec:
  syncWindows:
  - kind: deny
    schedule: "Mon-Fri 09:00-18:00"
    duration: "9h"
```



## 8) Clusters — Add/List/Remove Destinations

**Manage additional target clusters (multi‑cluster GitOps).**

```bash
argocd cluster list
argocd cluster add <KUBECONTEXT_NAME>
argocd cluster get <KUBECONTEXT_NAME> -o wide
argocd cluster rm <KUBECONTEXT_NAME>
```



## 9) ApplicationSet — Generate Many Apps (Multi‑cluster & Multi‑env at Scale)

**Install and use ApplicationSet to template and stamp out many Applications.**
(List/Cluster/Git/Matrix/Merge/SCM‑Provider/PR generators.)

```yaml
# apps/appset-list.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook
spec:
  goTemplate: true
  generators:
  - list:
      elements:
      - cluster: engineering-dev
        url: https://1.2.3.4
      - cluster: engineering-prod
        url: https://2.4.6.8
  template:
    metadata:
      name: 'guestbook-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        path: guestbook
        targetRevision: HEAD
      destination:
        server: '{{url}}'
        namespace: default
```

```bash
kubectl apply -n argocd -f apps/appset-list.yaml
```

> ApplicationSet supports **Matrix/Merge** generators to combine Git/cluster/other inputs; use **Progressive Syncs** to stage prod rollouts. ([Argo CD][5])



## 10) Health, Diff & Ignore‑Rules (SRE‑grade Observability)

**Understand health vs sync (and customize health for CRDs with Lua).**

```yaml
# Example: add a custom health check in argocd-cm for a CRD kind
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
data:
  resource.customizations.health.example.com_MyCRD: |
    hs = {}
    if obj.status ~= nil and obj.status.ready == true then
      hs.status = "Healthy"
    else
      hs.status = "Progressing"
    end
    return hs
```

**Diff & ignore differences:** ignore noisy fields (e.g., `spec.replicas`).

```yaml
# In Application spec
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```



## 11) Notifications (Slack/Webhook/Email)

**Subscribe with annotations (per app or project).**

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: "#deployments"
```

**Define triggers/templates (when & what to send).**

```yaml
# in argocd-notifications-cm
triggers:
  - name: on-sync-succeeded
    condition: app.status.operationState.phase == 'Succeeded'
    templates: [ app-sync-succeeded ]
```

> The Notifications controller ships a catalog of common triggers/templates you can reuse.



## 12) Helm & OCI: Best‑practice sources

**Helm as a source (Argo inflates with `helm template`; Argo manages lifecycle).**

```yaml
spec:
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 5.51.6
    helm:
      valuesObject:
        server:
          extraArgs: [--insecure]
```

**Use an OCI registry as an Application source** (charts or manifests from `oci://`).

```yaml
spec:
  source:
    repoURL: oci://registry-1.docker.io/bitnamicharts/nginx
    targetRevision: 15.9.0
    helm:
      valuesObject:
        service:
          type: ClusterIP
```



## 13) Secrets & Config Management Plugins (CMP)

**Use CMPs (e.g., `argocd-vault-plugin`, KSOPS) to render secrets at build time.**

> Note: The docs caution against manifest‑generation‑based secret injection; understand the tradeoffs and security posture before enabling.

```yaml
# argocd-cm snippet (registering a plugin)
data:
  configManagementPlugins: |
    - name: avp
      generate:
        command: ["argocd-vault-plugin", "generate", "."]
```

**Enable Kustomize plugins like KSOPS (SOPS‑encrypted secrets).**

```yaml
# Configure repo-server to allow plugins via Helm values or a patch,
# ensuring ksops binary is available and kustomize build options include --enable-alpha-plugins
```



## 14) Admin & Power‑User CLI (Day‑2 Operations)

**List resources (and orphans) owned by an app.** ([Argo CD][6])

```bash
argocd app resources my-app
argocd app resources my-app --orphaned
```

**Run built‑in or custom resource actions (e.g., restart Deployments).** ([Argo CD][7])

```bash
# See available actions
argocd app actions list my-app

# Restart all Deployments in the app
argocd app actions run my-app restart --kind Deployment --all
```

**Terminate a stuck operation; delete app (with cascade policy).**

```bash
argocd app terminate-op my-app

# Delete application and control propagation
argocd app delete my-app --cascade --propagation-policy foreground
```

**Patch or delete a single resource managed by the app (surgical fixes).**

```bash
# Delete a specific resource (force/orphan as needed)
argocd app delete-resource my-app --kind Deployment --group apps --namespace default --resource-name api --force
```

**CLI contexts, auth tokens, and relogin.**

```bash
argocd context             # switch between saved server contexts
argocd logout              # end session
argocd relogin             # refresh expired session
```



## 15) Real‑World Sync Options & Safety Nets

**Selective sync (ApplyOutOfSyncOnly):** reduce API pressure on large apps. ([Argo CD][3])

```bash
argocd app set big-app --sync-option ApplyOutOfSyncOnly=true
```

**Require confirmation before deleting critical resources.** ([Argo CD][3])

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Delete=confirm
```

**Sync windows** prevent/allow syncs by schedule for change‑freeze windows.

```yaml
spec:
  syncWindows:
  - kind: deny
    schedule: "Sat,Sun"
    duration: "48h"
```



## 16) App‑of‑Apps, Multi‑Source & Progressive Delivery

**App‑of‑Apps:** parent Application manages child Application manifests (folder of `Application` YAMLs), giving a declarative bootstrap. (Use label selectors to sync children.)

```bash
# Sync all children created by the parent (by label)
argocd app sync -l app.kubernetes.io/instance=platform-root
```

**Progressive syncs with ApplicationSet**: stage environments (dev→qa→prod at %), holding prod until manual approval. ([Argo CD][5])



## 17) Troubleshooting Checklist (Day‑2)

**Drift & reconcile:**

```bash
argocd app diff my-app            # What changed?
argocd app sync my-app            # Reconcile to desired
argocd app wait my-app --health   # Wait until healthy
```

**Visibility:**

```bash
argocd app get my-app             # Summary, health, sync
argocd app resources my-app       # Owned resources
argocd app logs my-app            # Pod logs
argocd app history my-app         # What/when deployed
```

**Operations:**

```bash
argocd app terminate-op my-app    # Kill stuck operation
argocd app rollback my-app 1      # Roll back to history ID 1
```

> The repo‑server caches generated manifests; reducing cache time or forcing a fresh build can help when external inputs (e.g., Helm remote bases) change without a Git commit. ([Argo CD][8])



## 18) Security & SSO (Pointers)

**Login modes:** local users, SSO (OIDC/SAML via your IdP). Use project roles + JWTs for scoped automation tokens instead of sharing admin.



## 19) Quick Command Index (Daily Use)

**Essentials**

```bash
argocd version
argocd login <server> [--sso]
argocd app create ...        # directory/kustomize/helm/OCI
argocd app get/list/diff
argocd app sync [--apply-out-of-sync-only]
argocd app wait --health --sync
argocd app history | argocd app rollback <id?>
argocd app logs/resources
argocd app delete --cascade --propagation-policy foreground
```

**Repos & Clusters**

```bash
argocd repo add/list/rm
argocd repocreds list
argocd cluster list/add/get/rm
```

**Projects & RBAC**

```bash
argocd proj list/create/delete
argocd proj role create/add-policy/create-token
```

**Actions & Maintenance**

```bash
argocd app actions list/run ...
argocd app terminate-op <app>
```

> You can view full command references for **`argocd app`**, **`argocd repo`**, **`argocd proj`**, **`argocd cluster`**, and more in the official docs. ([GitHub][1])



## 20) Copy‑Paste Lab: End‑to‑End Mini Scenario

1. **Install & login**

```bash
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd port-forward svc/argocd-server 8080:443 >/dev/null 2>&1 &
argocd admin initial-password -n argocd | tr -d '\n' | pbcopy   # copy pwd (macOS)
argocd login localhost:8080 --username admin --password "$(pbpaste)" --insecure
```

2. **Add repos and create apps**

```bash
argocd repo add https://github.com/argoproj/argocd-example-apps.git
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
```

3. **Enforce enterprise policies**

```bash
argocd proj create platform --dest https://kubernetes.default.svc,platform --src https://github.com/argoproj/argocd-example-apps.git
argocd app set guestbook --project platform
argocd app set guestbook --sync-policy automated --auto-prune --self-heal
argocd app set guestbook --sync-option ApplyOutOfSyncOnly=true
```

4. **Operate & recover**

```bash
argocd app diff guestbook
argocd app sync guestbook
argocd app wait guestbook --health --sync
argocd app history guestbook
argocd app rollback guestbook 1
```

---

## References & Further Reading

* **Getting Started / CLI / Port‑forward / First App** — install, access, login, cluster add, create & sync applications.
* **Login (CLI reference)** — `argocd login` usage & flags.
* **App commands** — create/sync/diff/history/rollback/logs/resources/wait.
* **Clusters (CLI)** — list/add/get/rm.
* **Repositories & Credentials** — repo add/list; credential templates; private repos; OCI Helm. ([GitHub][1])
* **Helm & OCI as sources** — Helm inflation; OCI references.
* **Sync options** — ApplyOutOfSyncOnly; delete confirmation. ([Argo CD][3])
* **Sync waves & hooks** — ordered deployments via annotations. ([Argo CD][4])
* **Projects/RBAC** — multi‑tenancy, roles and JWT tokens.
* **Sync windows** — cron‑like allow/deny schedules.
* **ApplicationSet** — controller intro, generators (List/Cluster/Git/Matrix/Merge/SCM/PR).
* **Health assessments & custom health** — built‑ins and Lua customization.
* **Diff customization** — ignore specific fields/managers.
* **Notifications** — subscriptions, triggers, catalog.
* **Config Management Plugins & secret management cautions**.
* **Repo‑server caching behavior** (why a “hard refresh” helps sometimes).

---

### Notes for Trainers

* The sequence mirrors real rollouts: **install → secure access → add repos/clusters → create apps → enforce policies → scale with ApplicationSet → Day‑2 ops**.
* All commands are **idempotent** or safe to re‑run in lab settings; adapt namespaces/repo URLs for your environment.


[1]: https://github.com/argoproj/argo-cd/blob/master/docs/user-guide/commands/argocd_repo.md?utm_source=chatgpt.com "argo-cd/docs/user-guide/commands/argocd_repo.md at master"
[2]: https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_app_sync/?utm_source=chatgpt.com "argocd app sync Command Reference - Argo CD"
[3]: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/?utm_source=chatgpt.com "Sync Options - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/?utm_source=chatgpt.com "Sync Phases and Waves - Argo CD - Read the Docs"
[5]: https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Progressive-Syncs/?utm_source=chatgpt.com "Progressive Syncs - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_app_resources/?utm_source=chatgpt.com "argocd app resources Command Reference - Argo CD"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/resource_actions/?utm_source=chatgpt.com "Resource Actions - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/?utm_source=chatgpt.com "Overview - Argo CD - Declarative GitOps CD for Kubernetes"
