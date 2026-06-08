# Kubernetes Setup for TodoApp

Kustomize configurations to deploy the TodoApp to Kubernetes.

## Structure

- **todoapp/** — Application workloads:
  - `auth` (Go, port 8080)
  - `core` (Node.js, port 3000)
  - `web` (frontend, port 80)
  - `mysql` (auth database)
  - `mongo` (core database)
- **components/** — Ingress routing rules

## Routing

| Path         | Service | Port |
| ------------ | ------- | ---- |
| `/api/auth`  | auth    | 8080 |
| `/api/tasks` | core    | 3000 |
| `/`          | web     | 80   |

## Environments

| Environment | Ingress Controller | Hostname              | Use Case               |
| ----------- | ------------------ | --------------------- | ---------------------- |
| dev         | NGINX              | todoapp.test          | Local (kind, minikube) |
| prod        | Traefik            | `todoapp.<IP>.nip.io` | VPS or cloud           |

## Prerequisites

- Kubernetes cluster with `kubectl`
- **Dev**: Install NGINX Ingress Controller:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
  ```
- **Prod**: Install Traefik (Helm):
  ```bash
  helm repo add traefik https://traefik.github.io/charts
  helm install traefik traefik/traefik --namespace traefik --create-namespace
  ```

## Deploy

Run commands from the `infra/` directory.

### Development

```bash
kubectl apply -k k8s/todoapp/overlays/dev
kubectl apply -k k8s/components/overlays/dev
```

### Production

1. Edit the public IP in `k8s/components/overlays/prod/kustomization.yaml` (replace `YOUR_VPS_IP`).
2. (Optional) Update image tags in `k8s/todoapp/overlays/prod/kustomization.yaml`.
3. Deploy:
   ```bash
   kubectl apply -k k8s/todoapp/overlays/prod
   kubectl apply -k k8s/components/overlays/prod
   ```

## Tips

- Deploy `todoapp` workloads before or together with the Ingress.
- `nip.io` gives you a working hostname from any public IP with no DNS setup.
- Base images use `imagePullPolicy: Always`.
- For real production, add TLS with cert-manager and use a proper domain.
