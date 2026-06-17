# Easy Steps: Deploy TodoApp on Kubernetes (k3s + ArgoCD)

Fast path to run the full stack on a VPS using k3s and ArgoCD (GitOps).

This guide covers both environments:

- **stage**: Quick testing using a `nip.io` hostname (HTTP only, no real DNS required). Ideal for daily work and fast iteration.
- **prod**: Real production using the custom domain `todoapp.store` + automatic TLS via cert-manager + Let's Encrypt.

You can deploy **stage**, **prod**, or both side-by-side on the same cluster.

## Warnings

- This is a **learning project**, not production-ready.
- Storage is ephemeral (`hostPath`). Data is lost on restart/recreate.
- The DigitalOcean Droplet incurs hourly cost. Run `terraform destroy` when done.
- You need a DigitalOcean account + API token (with Droplet + SSH Key write scopes) if using the Terraform example.

## Prerequisites

- Terraform installed (optional, only if provisioning a new Droplet)
- Git + SSH key on your machine
- DigitalOcean API token exported as `TF_VAR_do_token` (if using Terraform)
- For **prod** only: ability to create a DNS A record and open firewall ports 80/443.

Generate the expected key if you don't have it (for Terraform example):

```bash
ssh-keygen -t ed25519 -C "todoapp" -f ~/.ssh/id_dalthonmh_digitalocean
```

## 1. Clone and Provision the VPS (optional)

```bash
git clone https://github.com/dalthonmh/todoapp
cd todoapp/infra/terraform

terraform init
terraform plan
terraform apply   # confirm with "yes"
```

Copy the IP from the output (`cp01_ip`) or run `terraform output` later.

## 2. SSH into the VPS

```bash
ssh -i ~/.ssh/id_dalthonmh_digitalocean root@<VPS_IP>
```

## 3. Install git and clone the repo on the server

```bash
apt update && apt install git -y
git clone https://github.com/dalthonmh/todoapp
cd todoapp
```

## 4. Install k3s + kubectl

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# k3s (includes Traefik by default)
curl -sfL https://get.k3s.io | sh -

# Configure kubeconfig for the current user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

kubectl get nodes   # should show Ready
```

Optional but recommended aliases:

```bash
cat >> ~/.bashrc << 'EOF'
alias k=kubectl
complete -o default -F __start_kubectl k
source <(kubectl completion bash 2>/dev/null || true)
EOF
source ~/.bashrc
```

## 5. Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl get pods -n argocd -w
```

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

## 6. Access the ArgoCD UI (from the VPS)

Expose ArgoCD:

```bash
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:80
```

(Use `&` or run in tmux/screen for persistence.)

Open in your browser: `http://<VPS_IP>:8080`

- Username: `admin`
- Password: the one printed in the previous step

## 7. Create the ArgoCD Project (recommended once)

```bash
kubectl apply -f infra/argocd/projects/todoapp-project.yaml
```

This creates the `todoapp` project that all our Applications will belong to.

## 8. Deploy the Stage environment (quick testing - recommended)

Stage gives you a working public URL immediately using nip.io (no DNS changes). It is HTTP only and perfect for testing before going to real prod.

**Important**: The stage overlay currently hardcodes `todoapp.159.203.120.126.nip.io`. If your VPS has a different public IP:

1. Edit the file and replace the IP:
   ```bash
   vim infra/k8s/components/overlays/stage/kustomization.yaml
   ```
2. Update the `value:` under the host patch to `todoapp.<YOUR_VPS_PUBLIC_IP>.nip.io`

Then bootstrap:

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-stage.yaml
```

After the bootstrap syncs, ArgoCD will create:

- `todoapp-stage`
- `components-stage`

Go to the ArgoCD UI and **SYNC** the `todoapp-bootstrap-stage` (or the two child apps).

Access the app at the hostname defined in the stage overlay, e.g.:

```
http://todoapp.159.203.120.126.nip.io
```

See [k8s/README.md](k8s/README.md) for the exact Kustomize commands (manual, without ArgoCD) and more environment details.

## 9. Deploy the Production environment (real domain + TLS)

Use this when you want the real `https://todoapp.store` with valid certificates.

### Prerequisites

- Create a DNS **A record**: `todoapp.store` → your VPS public IP.
- Open inbound TCP ports **80 and 443** in your cloud provider firewall / security group.
- The domain must resolve before requesting the certificate.

### One-time: Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml

# Wait for it
kubectl wait --namespace cert-manager --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s
```

(While testing you can temporarily switch the overlay to the `letsencrypt-staging` issuer to avoid rate limits — see comments in the prod overlay.)

### Bootstrap prod

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-prod.yaml
```

After sync, ArgoCD creates:

- `todoapp-prod`
- `components-prod`

Sync in the ArgoCD UI.

Access: **https://todoapp.store**

It can take a couple of minutes for the certificate to be issued. Check with:

```bash
kubectl get certificate
kubectl describe certificate todoapp-store-tls
```

You can run both stage and prod at the same time (they use different hostnames).

## Useful Commands

```bash
# On the server
kubectl get pods
kubectl get ingress
k get all                 # if alias is set
kubectl get applications -n argocd

# Watch a specific app
# Login
argocd login localhost:8080 --username admin --password password --insecure
argocd app get todoapp-stage
argocd app sync todoapp-stage
```

From your laptop you can also use `kubectl` against the cluster by copying the kubeconfig, or just SSH + port-forward ArgoCD.

## Cleanup (if using Terraform)

From your local machine (in `infra/terraform`):

```bash
terraform destroy   # confirm with "yes"
```

This removes the Droplet.
