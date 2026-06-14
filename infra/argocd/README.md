# ArgoCD Deployment for TodoApp

This directory contains the necessary manifests and documentation to manage the TodoApp Kubernetes deployments using **ArgoCD** (GitOps).

It builds on top of the existing Kustomize setup in [`infra/k8s/`](../k8s/README.md).

## How It Works

The existing Kustomize structure is reused directly:

- `infra/k8s/todoapp/overlays/{dev,prod}` — Application workloads (auth, core, web, mysql, mongo)
- `infra/k8s/components/overlays/{dev,prod}` — Ingress configuration

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
kubectl port-forward  --address 0.0.0.0 svc/argocd-server -n argocd  8080:80
kubectl port-forward svc/argocd-server -n argocd  8080:80
```

Default admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Repository Paths (Important)

When configuring ArgoCD Applications, paths are **relative to the repository root**:

| Component  | Dev Path                            | Prod Path                            |
| ---------- | ----------------------------------- | ------------------------------------ |
| todoapp    | `infra/k8s/todoapp/overlays/dev`    | `infra/k8s/todoapp/overlays/prod`    |
| components | `infra/k8s/components/overlays/dev` | `infra/k8s/components/overlays/prod` |

> Note: This differs from the `kubectl apply -k` commands in the main k8s README (which assume you are inside the `infra/` directory).

### Using your own fork

All example Application and bootstrap files contain:

```yaml
repoURL: https://github.com/dalthonmh/todoapp.git
```

If you are working from a fork, **update the `repoURL`** in the following files before applying them:

- `infra/argocd/applications/dev/*.yaml`
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

**For Development:**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-dev.yaml
```

**For Stage (quick testing - nip.io):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-stage.yaml
```

**For Production (real domain todoapp.store + TLS):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-prod.yaml
```

After applying the bootstrap Application(s), ArgoCD will automatically create and manage the child Applications:

- `todoapp-dev` + `components-dev`
- `todoapp-stage` + `components-stage` (nip.io, HTTP only)
- `todoapp-prod` + `components-prod` (real domain + HTTPS) — see `infra/STAGE.md`

You can also create the bootstrap Application through the ArgoCD UI by pointing to the `bootstrap/` path.

## Manual Application Creation (Alternative)

If you prefer not to use the App of Apps pattern, apply the manifests in this order:

```bash
# 1. Project (once)
kubectl apply -f infra/argocd/projects/todoapp-project.yaml

# 2. Development Applications
kubectl apply -f infra/argocd/applications/dev/todoapp.yaml
kubectl apply -f infra/argocd/applications/dev/components.yaml

# Or for Production
kubectl apply -f infra/argocd/applications/prod/todoapp.yaml
kubectl apply -f infra/argocd/applications/prod/components.yaml
```

## Environment Details

### Development (dev)

- Uses NGINX Ingress Controller (`ingressClassName: nginx`)
- Host: `todoapp.test` (add `127.0.0.1 todoapp.test` to your `/etc/hosts`)
- Everything deployed to `default` namespace
- Recommended for kind / minikube / local clusters

**Before deploying**, make sure the NGINX Ingress Controller is installed (see [`infra/k8s/README.md`](../k8s/README.md)).

### Production (prod)

- Uses Traefik Ingress Controller (`ingressClassName: traefik`)
- Host uses `nip.io` pattern: `todoapp.<YOUR_VPS_IP>.nip.io`
- Everything deployed to `default` namespace

**Important GitOps Limitation**:

The current prod overlay hardcodes the IP in `infra/k8s/components/overlays/prod/kustomization.yaml` (`todoapp.YOUR_VPS_IP.nip.io`).

In a pure GitOps workflow this is not ideal because:

- The same repo may be used for multiple clusters.
- You don't want to commit cluster-specific IPs.

**Recommended improvements for production** (choose one):

1. Use a real domain + cert-manager + TLS.
2. Create environment-specific overlays or use Kustomize `components` + replacements.
3. Pass the hostname via ArgoCD Application parameters (using `source.kustomize`).
4. Use separate branches or directories per cluster.

For now, the provided prod Applications point to the existing overlay. You will need to edit the IP in the repo (or fork) before it will work correctly.

## Order of Deployment

The `todoapp` workloads (Deployments + Services) should exist before the Ingress rules are applied.

With separate Applications we recommend one of the following:

- Sync `todoapp-*` first, then `components-*`.
- Or add sync waves (see example in the Application files).
- Or combine both into a single Application that points to a combined kustomize root (more advanced).

The provided Application manifests include a `syncWave` annotation to help with ordering.

## Sync Policy

The development Applications are configured with automated sync + self-heal + prune by default (good for fast iteration).

Production Applications are set to manual sync by default (safer).

You can change this in the Application YAMLs or via the ArgoCD UI.

## Next Steps / Improvements

- Add an ArgoCD Project (`infra/argocd/projects/`) for better RBAC and namespace restrictions.
- Use ApplicationSets instead of multiple static Application files.
- Parameterize the prod hostname using Kustomize or Helm.
- Add health checks, resource requests, and proper secrets management.
- Integrate with a CI pipeline that updates image tags in the overlays.

## Useful ArgoCD Commands

```bash
# List applications
argocd app list

# Watch sync status
argocd app get todoapp-dev -w

# Force a sync
argocd app sync todoapp-dev

# View logs of the application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

See the individual files in `applications/` and `bootstrap/` for the actual manifests.
