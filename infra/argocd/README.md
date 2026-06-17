# ArgoCD Deployment for TodoApp

This directory contains the necessary manifests and documentation to manage the TodoApp Kubernetes deployments using **ArgoCD** (GitOps).

It builds on top of the existing Kustomize setup in [`infra/k8s/`](../k8s/README.md).

## How It Works

The existing Kustomize structure is reused directly:

- `infra/k8s/todoapp/overlays/{dev,stage,prod}` — Application workloads (auth, core, task, web, mysql, mongo, postgres)
- `infra/k8s/components/overlays/{dev,stage,prod}` — Ingress configuration (and TLS for prod)

ArgoCD Applications point directly to these Kustomize overlay paths. ArgoCD natively supports Kustomize, so no extra build steps are needed.

## Prerequisites

1. A Kubernetes cluster.
2. ArgoCD installed in the cluster (in the `argocd` namespace).
3. `kubectl` configured to talk to the cluster.
4. The Git repository accessible by ArgoCD (public repo or configured credentials / GitHub App / deploy key).

**Install ArgoCD** (if not already installed):

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Access the ArgoCD UI (example with port-forward):

```bash
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:80
```

Default admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Repository Paths (Important)

When configuring ArgoCD Applications, paths are **relative to the repository root**:

| Environment | todoapp overlay path               | components overlay path               |
| ----------- | ---------------------------------- | ------------------------------------- |
| dev         | `infra/k8s/todoapp/overlays/dev`   | `infra/k8s/components/overlays/dev`   |
| stage       | `infra/k8s/todoapp/overlays/stage` | `infra/k8s/components/overlays/stage` |
| prod        | `infra/k8s/todoapp/overlays/prod`  | `infra/k8s/components/overlays/prod`  |

> Note: These paths are used both by the example Application manifests and by manual `kubectl apply -k` commands (the latter assume you run them from the repository root).

### Using your own fork

All example Application and bootstrap files contain:

```yaml
repoURL: https://github.com/dalthonmh/todoapp.git
```

If you are working from a fork, **update the `repoURL`** in the following files before applying them:

- `infra/argocd/applications/dev/*.yaml`
- `infra/argocd/applications/stage/*.yaml`
- `infra/argocd/applications/prod/*.yaml`
- `infra/argocd/bootstrap/*.yaml`

## Recommended GitOps Approach: App of Apps + Project

We use the **App of Apps** pattern together with an ArgoCD `AppProject` for better organization and security.

### 1. (Recommended) Create the Project first

```bash
kubectl apply -f infra/argocd/projects/todoapp-project.yaml
```

This creates a project called `todoapp` that the Applications will belong to.

### 2. Bootstrap the Applications (App of Apps)

From the root of the repository:

**2.1. For Development (local / kind / minikube):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-dev.yaml
```

**2.2. For Stage (quick testing - nip.io, HTTP only):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-stage.yaml
```

**2.3. For Production (real domain `todoapp.store` + TLS):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-prod.yaml
```

After applying the bootstrap Application(s), ArgoCD will automatically create and manage the child Applications:

- `todoapp-dev` + `components-dev`
- `todoapp-stage` + `components-stage` (nip.io hostname from the overlay, HTTP only)
- `todoapp-prod` + `components-prod` (real domain `todoapp.store` + HTTPS via cert-manager)

You can also create the bootstrap Application through the ArgoCD UI by pointing to the `bootstrap/` path.

## Useful ArgoCD Commands

```bash
# Login
argocd login localhost:8080 \
  --username admin \
  --password password \
  --insecure

# List applications
argocd app list

# Watch sync status
argocd app get todoapp-stage -w

# Force a sync
argocd app sync todoapp-stage

# View logs of the application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

See the individual files in `applications/` and `bootstrap/` for the actual manifests.
