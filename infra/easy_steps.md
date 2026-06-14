# Easy Steps: Deploy TodoApp on Kubernetes (k3s + ArgoCD)

Fast path to run the full stack on a VPS using k3s and ArgoCD (GitOps). Uses nip.io for hostname resolution so no DNS setup is needed.

## Warnings

- This is a **learning project**, not production-ready.
- Storage is ephemeral (`hostPath`). Data is lost on restart/recreate.
- The DigitalOcean Droplet incurs hourly cost. Run `terraform destroy` when done.
- You need a DigitalOcean account + API token (with Droplet + SSH Key write scopes).

## Prerequisites

- Terraform installed
- Git + SSH key (the Terraform config expects `~/.ssh/id_dalthonmh_digitalocean` by default — adapt `main.tf` if using another key)
- DigitalOcean API token exported as `TF_VAR_do_token`

Generate the expected key if you don't have it:

```bash
ssh-keygen -t ed25519 -C "todoapp" -f ~/.ssh/id_dalthonmh_digitalocean
```

## 1. Clone and Provision the VPS

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

# k3s
curl -sfL https://get.k3s.io | sh -

# Configure kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

kubectl get nodes   # should show Ready
```

Optional aliases:

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

# Wait for pods
kubectl get pods -n argocd -w
```

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

## 6. Access the ArgoCD UI

From the VPS, expose ArgoCD on all interfaces:

```bash
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:80
```

(Append `&` to background it, or run inside tmux/screen for persistence.)

Open in your browser: `http://<VPS_IP>:8080`

- Username: `admin`
- Password: the one printed above

## 7. Configure the production hostname (critical)

Edit the prod overlay and replace the IP:

```bash
# Use your preferred editor
vim infra/k8s/components/overlays/prod/kustomization.yaml
```

Find and update this value with your real VPS IP:

```yaml
value: todoapp.<VPS_IP>.nip.io
```

Example:

```yaml
value: todoapp.203.0.113.42.nip.io
```

Save the file. Because ArgoCD watches the repo, the change will be picked up on the next sync.

## 8. Bootstrap the applications (App of Apps)

```bash
kubectl apply -f infra/argocd/projects/todoapp-project.yaml
kubectl apply -f infra/argocd/bootstrap/app-of-apps-prod.yaml
```

This creates:

- `todoapp-bootstrap-prod` (parent)
- `todoapp-prod` (services)
- `components-prod` (Ingress)

## 9. Sync in ArgoCD

1. Go to the ArgoCD UI.
2. You should see the three applications.
3. Click **SYNC** on `todoapp-bootstrap-prod` (or sync the children individually).
4. Wait until they show **Healthy + Synced** (green).

## Access the App

```bash
http://todoapp.<VPS_IP>.nip.io
```

## Useful Commands

```bash
kubectl get pods
kubectl get ingress
k get all                 # if you set up the alias
kubectl get applications -n argocd
```

## Cleanup

From your local machine (in `infra/terraform`):

```bash
terraform destroy   # confirm with "yes"
```
