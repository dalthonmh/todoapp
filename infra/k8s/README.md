# Kubernetes Setup for TodoApp

Kustomize-based deployment for the TodoApp microservices.

## Structure

- **todoapp/**: Application services (auth, core, task, web, mysql, mongo, postgres)
- **components/**: Shared Ingress configuration

### Routing

| Path         | Service | Port |
| ------------ | ------- | ---- |
| `/api/auth`  | auth    | 8080 |
| `/api/tasks` | task    | 8085 |
| `/`          | web     | 80   |

### Environments

| Environment | Ingress | Hostname                              | TLS     | Typical Use                          |
| ----------- | ------- | ------------------------------------- | ------- | ------------------------------------ |
| dev         | NGINX   | `todoapp.test`                        | No      | Local (kind / minikube)              |
| stage       | Traefik | `todoapp.<IP>.nip.io` (see overlay)   | No      | Quick testing on VPS (HTTP only)     |
| prod        | Traefik | `todoapp.store`                       | Yes     | Real domain + TLS (cert-manager)     |

> The exact `stage` hostname is defined in `infra/k8s/components/overlays/stage/kustomization.yaml`.

## Prerequisites

- A running Kubernetes cluster with `kubectl` configured.
- **Ingress controller** (choose according to your environment):
  - **dev**: NGINX Ingress Controller (example for kind):
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller --timeout=120s
    ```
  - **stage / prod**: Traefik (comes pre-installed with k3s). For other clusters install via Helm if needed.
- **Production only**:
  - `todoapp.store` must have an A record pointing to your server's public IP.
  - Firewall rules allowing inbound TCP 80 and 443.
  - cert-manager installed (see Production section).

## Deploy

All `kubectl apply -k` examples below are written to be run from the **repository root**.

### Development (dev)

```bash
kubectl apply -k infra/k8s/todoapp/overlays/dev
kubectl apply -k infra/k8s/components/overlays/dev
```

Add the hostname to your local machine:

```bash
# For kind/minikube the ingress usually runs on localhost
echo "127.0.0.1 todoapp.test" | sudo tee -a /etc/hosts
```

Open: http://todoapp.test

### Stage (quick testing / pre-prod)

Stage uses a `nip.io` hostname so you get a working DNS name for any public IP without touching real DNS. It is HTTP only (no TLS) and is ideal for fast iteration on a VPS.

```bash
kubectl apply -k infra/k8s/todoapp/overlays/stage
kubectl apply -k infra/k8s/components/overlays/stage
```

Access the app at the hostname defined in the stage overlay, e.g.:

```
http://todoapp.159.203.120.126.nip.io
```

> Make sure Traefik is the default ingress controller (default on k3s).

**Using ArgoCD (recommended for remote environments)**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-stage.yaml
```

See [infra/argocd/README.md](../argocd/README.md) and [infra/README.md](../README.md) for the full GitOps + VPS workflow.

### Production (real domain + TLS)

Production deploys to the real domain `todoapp.store` with automatic HTTPS via Let's Encrypt + cert-manager.

#### One-time setup

1. **Install cert-manager**:

   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
   kubectl wait --namespace cert-manager --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller --timeout=120s
   ```

2. (Recommended while testing) Temporarily use the staging issuer to avoid Let's Encrypt rate limits:
   - Edit `infra/k8s/components/overlays/prod/kustomization.yaml`
   - Change `letsencrypt-prod` → `letsencrypt-staging` in the annotation.
   - Later switch back to `letsencrypt-prod` for real certificates.

3. Ensure your DNS is ready:
   - Create an **A record** for `todoapp.store` → your VPS public IP.
   - Open ports 80 and 443 in your cloud firewall / security group.

#### Deploy

```bash
# 1. Workloads first (recommended)
kubectl apply -k infra/k8s/todoapp/overlays/prod

# 2. Ingress + TLS configuration (includes ClusterIssuer)
kubectl apply -k infra/k8s/components/overlays/prod
```

You can also run both commands together.

Access: https://todoapp.store

> It can take 1–3 minutes for the certificate to be issued and become Ready.  
> Check progress with:
> ```bash
> kubectl get certificate
> kubectl describe certificate todoapp-store-tls
> ```

**Using ArgoCD (recommended)**

```bash
# One-time: install cert-manager as shown above (or via ArgoCD Helm chart)

kubectl apply -f infra/argocd/bootstrap/app-of-apps-prod.yaml
```

After the bootstrap Application syncs, ArgoCD will create:
- `todoapp-prod`
- `components-prod`

Monitor with `argocd app get todoapp-bootstrap-prod -w` or the ArgoCD UI.

See [infra/README.md](../README.md) for the practical VPS deployment workflow (stage vs prod).

## Preview Rendered Manifests

```bash
# Development
kubectl kustomize infra/k8s/todoapp/overlays/dev
kubectl kustomize infra/k8s/components/overlays/dev

# Stage
kubectl kustomize infra/k8s/todoapp/overlays/stage
kubectl kustomize infra/k8s/components/overlays/stage

# Production
kubectl kustomize infra/k8s/todoapp/overlays/prod
kubectl kustomize infra/k8s/components/overlays/prod
```

## Tips

- Apply the `todoapp` workloads **before or together with** the `components` (Ingress) overlays. The components overlay has a higher sync wave when using ArgoCD.
- All base images use `imagePullPolicy: Always`.
- `nip.io` gives you free wildcard DNS for any public IP (very convenient for stage).
- For production, prefer the real domain + cert-manager over nip.io.
- You can have **stage and prod** running side-by-side on the same cluster (they use different hostnames).
- Common next improvements:
  - Pin image tags per environment instead of `Always`.
  - Add resource requests/limits, HPA, PodDisruptionBudgets.
  - Use sealed-secrets or external-secrets for sensitive values.
  - Separate namespaces per environment.

## Quick Cluster on a VPS (k3s)

Useful for both **stage** and **prod**.

1. Install kubectl (on the VPS):

   ```bash
   curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

2. (Optional) Add convenient aliases:

   ```bash
   cat >> ~/.bashrc << 'EOF'
   alias k=kubectl
   complete -o default -F __start_kubectl k
   source <(kubectl completion $(basename $SHELL))
   EOF
   source ~/.bashrc
   ```

3. Install k3s (includes Traefik by default):

   ```bash
   curl -sfL https://get.k3s.io | sh -
   mkdir -p ~/.kube
   sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
   sudo chown $USER:$USER ~/.kube/config
   kubectl get nodes
   ```

4. Then choose:

   - For fast testing → follow the **Stage** steps above.
   - For the real domain → follow the **Production** steps (DNS + cert-manager required).

## Related Documentation

- [infra/README.md](../README.md) — Practical step-by-step guide for k3s + ArgoCD on a VPS (covers deploying stage and prod)
- [infra/argocd/README.md](../argocd/README.md) — Detailed GitOps with ArgoCD (App of Apps, manual applications, sync policies, etc.)
- Root [README.md](../../README.md) — Project overview and high-level navigation

For troubleshooting ArgoCD applications:

```bash
argocd app list
argocd app sync todoapp-stage
argocd app logs components-prod -c argocd-application-controller
```
