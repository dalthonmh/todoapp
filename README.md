# TodoApp

A small microservices-based ToDo application built as a learning project to practice and experiment with cloud infrastructure, containers, Kubernetes, Docker Compose, and Infrastructure as Code.

## The Application

The system consists of the following main services:

| Service | Tech Stack                     | Responsibility                        | Database        |
| ------- | ------------------------------ | ------------------------------------- | --------------- |
| auth    | Go + Gin + GORM + JWT          | User registration and login           | MySQL           |
| core    | Node.js + Express              | Tasks CRUD API (legacy/first version) | MongoDB         |
| task    | Java + Spring Boot             | Tasks CRUD API (improved, optional)   | PostgreSQL / H2 |
| web     | Vue 3 + Vite (served by Nginx) | Frontend UI                           | -               |

An NGINX gateway (in the Docker Compose setup) or an Ingress (in Kubernetes) routes traffic:

- `/api/auth` → auth service
- `/api/tasks` → task service (by default) or core (legacy)
- `/` → web frontend

## Tasks API: Core vs Task (Optional Improved Version)

The `/api/tasks` functionality has two implementations:

- **`todoapp-core`** (original / first version):  
  Built with Node.js + Express + MongoDB. This was the initial implementation of the tasks API.

- **`todoapp-task`** (improved, **optional** version):  
  Built with Java + Spring Boot + Spring Data JPA. It offers the same REST API (`/api/tasks`) but is considered the more modern and improved implementation.
  - Supports in-memory H2 (development) or PostgreSQL (production-like).
  - Includes actuator endpoints for health checks.
  - Uses the same JWT authentication mechanism as `todoapp-auth` (must share the `JWT_SECRET`).

**Important**:

- Both services are now API-compatible. The frontend only uses `id` (we updated the legacy core to return `id` instead of Mongo's `_id`).
- You can use either one (or switch between them).
- In the Kubernetes manifests (`infra/k8s/`), the Ingress routes `/api/tasks` to the `task` service by default, and a `postgres` database is included for it.
- The legacy `core` + `mongo` stack is still present if you prefer the original implementation.
- The Docker Compose example in `infra/docker/` currently uses the legacy `core` service for tasks (with MongoDB).
- See [todoapp-task/README.md](todoapp-task/README.md) for specific instructions on the Java service (endpoints, authentication, local run, etc.).

## Repository Contents

This repository focuses on **deployment and infrastructure**:

- `todoapp-auth/`, `todoapp-core/`, `todoapp-task/`, `todoapp-web/` — Source code of the services (for building images or local development)
- `infra/k8s/` — Kubernetes manifests using Kustomize (dev + prod overlays)
- `infra/docker/` — Docker Compose setup for running the full stack
- `infra/terraform/` — Infrastructure as Code examples (e.g. DigitalOcean Droplet)
- `infra/sample/` — Example database manifests

> **Note**: The individual microservices are primarily developed in their own repositories:
>
> - https://github.com/dalthonmh/todoapp-auth
> - https://github.com/dalthonmh/todoapp-core
> - https://github.com/dalthonmh/todoapp-task
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

See [infra/terraform/README.md](infra/terraform/README.md) for usage.

## Important Notes

- This is a **learning / practice project**. Many things are intentionally simplified:
  - Database credentials and JWT secrets are hardcoded.
  - Docker Compose and Kubernetes examples use `hostPath` volumes (data is not durable).
- For real environments you should introduce Kubernetes Secrets, proper PersistentVolumes, TLS (cert-manager), image versioning, and CI/CD.
- `todoapp-task/` is the improved Java/Spring Boot implementation of the tasks API (optional replacement for the tasks part of `todoapp-core`). It is actively used in the Kubernetes setup.

## Project Goals

The main goal of this repository is to provide a realistic but manageable example for practicing:

- Multi-service application deployment
- Kubernetes with Kustomize
- Docker Compose for local and server environments
- Infrastructure as Code with Terraform
- Different environments (dev vs prod)

Feel free to explore, break things, and improve the manifests!
