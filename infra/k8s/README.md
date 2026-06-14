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

| Environment | Ingress | Hostname                            | Typical Use                          |
| ----------- | ------- | ----------------------------------- | ------------------------------------ |
| dev         | NGINX   | todoapp.test                        | Local (kind/minikube)                |
| stage       | Traefik | `todoapp.159.203.120.126.nip.io`    | Quick testing on VPS (HTTP only)     |
| prod        | Traefik | `todoapp.store`                     | Real domain + TLS (cert-manager)     |

> See [../STAGE.md](../STAGE.md) for details on the `stage` vs `prod` environments and how to deploy them with ArgoCD.

## Prerequisites

- A running Kubernetes cluster with `kubectl` configured.
- Ingress controller:
  - **Dev**: Install NGINX Ingress (example for kind):
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller --timeout=120s
    ```
  - **Prod**: k3s comes with Traefik pre-installed. For other clusters, install Traefik via Helm if needed.

## Deploy

Run all commands from the `infra/` directory.

### Development

```bash
kubectl apply -k k8s/todoapp/overlays/dev
kubectl apply -k k8s/components/overlays/dev
```

Add this line to your `/etc/hosts`:

```
<cluster-ip> todoapp.test
```

Then open http://todoapp.test

### Production

1. Edit the public IP in `k8s/components/overlays/prod/kustomization.yaml`:
   - Replace `YOUR_VPS_IP` with your server's public IP.

2. (Optional) Update image tags if you built new versions (edit the base deployments or create image overrides in the prod overlay).

3. Deploy:

```bash
kubectl apply -k infra/k8s/todoapp/overlays/prod
kubectl apply -k infra/k8s/components/overlays/prod
```

Access the app at:

```
http://todoapp.<YOUR_VPS_IP>.nip.io
```

## Tips

- Apply `todoapp` workloads before or together with the Ingress components.
- `nip.io` provides free DNS for any public IP (no extra configuration needed).
- All base images use `imagePullPolicy: Always`.
- For real production, add TLS using cert-manager + a real domain.
- You can preview the rendered manifests with:
  ```bash
  kubectl kustomize k8s/todoapp/overlays/prod
  ```

## Quick Cluster on a VPS

If you need a simple single-node cluster:

1. Install kubectl

```bash
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

2. Set the alias

```bash
cat >> ~/.bashrc << 'EOF'
# Kubernetes aliases y autocompletado
alias k=kubectl
complete -o default -F __start_kubectl k
source <(kubectl completion $(basename $SHELL))
EOF
```

3. Reload the configuration

```bash
source ~/.bashrc
```

4. On a Debian/Ubuntu VPS install k3s

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
kubectl get nodes
```

Then follow the Production steps above. k3s includes Traefik by default.
