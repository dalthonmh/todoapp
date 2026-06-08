# TodoApp

A small microservices-based ToDo application built as a learning project to practice and experiment with cloud infrastructure, containers, Kubernetes, Docker Compose, and Infrastructure as Code.

## The Application

The system consists of three main services:

| Service | Tech Stack                     | Responsibility              | Database |
| ------- | ------------------------------ | --------------------------- | -------- |
| auth    | Go + Gin + GORM + JWT          | User registration and login | MySQL    |
| core    | Node.js + Express              | Tasks CRUD API              | MongoDB  |
| web     | Vue 3 + Vite (served by Nginx) | Frontend UI                 | -        |

An NGINX gateway (in the Docker Compose setup) or an Ingress (in Kubernetes) routes traffic:

- `/api/auth` → auth service
- `/api/tasks` → core service
- `/` → web frontend

## Repository Contents

This repository focuses on **deployment and infrastructure**:

- `todoapp-auth/`, `todoapp-core/`, `todoapp-web/` — Source code of the services (for building images or local development)
- `infra/k8s/` — Kubernetes manifests using Kustomize (dev + prod overlays)
- `infra/docker/` — Docker Compose setup for running the full stack
- `infra/terraform/` — Infrastructure as Code examples (e.g. DigitalOcean Droplet)
- `infra/sample/` — Example database manifests

> **Note**: The individual microservices are primarily developed in their own repositories:
>
> - https://github.com/dalthonmh/todoapp-auth
> - https://github.com/dalthonmh/todoapp-core
> - https://github.com/dalthonmh/todoapp-web

## Getting Started

### 1. Run a Single Service (Development)

Each service has its own `docker-compose.yml` and README:

```bash
# Example: run the auth service locally
cd todoapp-auth
docker compose up -d --build
```

See the README inside each service folder for details and available endpoints.

### 2. Run the Full Stack with Docker Compose

A complete environment (all services + databases + nginx gateway) is available in `infra/docker/`:

```bash
cd infra/docker
cp .env.sample .env   # edit credentials if needed
docker compose up -d --build
```

Access the app at http://localhost.

See [infra/docker/README.md](infra/docker/README.md) for more details.

### 3. Deploy to Kubernetes

Kubernetes manifests are located in `infra/k8s/`.

**Recommended local setup**: Use [kind](https://kind.sigs.k8s.io/) + NGINX Ingress.

Full instructions (including cluster creation, Ingress controller, dev/prod deployments, and how to access the app) are in:

→ **[infra/k8s/README.md](infra/k8s/README.md)**

Quick example for local development:

```bash
# 1. Create a kind cluster with ingress ports (see k8s README for full config)
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
EOF

# Note: If you need to delete an existing cluster before starting, run: `kind delete cluster --name kind`

# 2. Install NGINX Ingress Controller (for kind)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 3. Deploy the application + ingress
kubectl apply -k infra/k8s/todoapp/overlays/dev
kubectl apply -k infra/k8s/components/overlays/dev

# 4. Add to /etc/hosts: 127.0.0.1 todoapp.test
# Then open http://todoapp.test
```

### 4. Infrastructure Provisioning

Terraform configurations for provisioning servers (e.g. DigitalOcean Droplets) are in `infra/terraform/`.

See [infra/terraform/readme.md](infra/terraform/readme.md) for usage.

## Important Notes

- This is a **learning / practice project**. Many things are intentionally simplified:
  - Database credentials and JWT secrets are hardcoded.
  - Docker Compose and Kubernetes examples use `hostPath` volumes (data is not durable).
- For real environments you should introduce Kubernetes Secrets, proper PersistentVolumes, TLS (cert-manager), image versioning, and CI/CD.
- The `todoapp-task/` directory contains an older Java/Spring version and is not part of the current active stack.

## Project Goals

The main goal of this repository is to provide a realistic but manageable example for practicing:

- Multi-service application deployment
- Kubernetes with Kustomize
- Docker Compose for local and server environments
- Infrastructure as Code with Terraform
- Different environments (dev vs prod)

Feel free to explore, break things, and improve the manifests!
