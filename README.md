# ToDo App on Kubernetes

This application was designed to practice and test cloud infrastructure deployments.

## Installation

### Clone repositories

All microservices are available on GitHub:

```sh
git clone https://github.com/dalthonmh/todoapp-auth
git clone https://github.com/dalthonmh/todoapp-core
git clone https://github.com/dalthonmh/todoapp-web
```

To run each project individually, navigate into their respective folders and follow their installation steps.

## Kubernetes Deployment

**Local Environment Setup**

We will use [kind](https://kind.sigs.k8s.io/) to run a local Kubernetes cluster using Docker.

### 1. Create the cluster

```sh
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
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

> Note: If you need to delete an existing cluster before starting, run: `kind delete cluster --name kind`

### 2. Install NGIN Ingress Controller

Apply the [Ingress Nginx](https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/kind/deploy.yaml) manifest compatible with Kind:

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

> Note: If you have created a cluster with more than one node, make sure that the ingress-nginx-controller pod is running in the Control Plane.

### 3. Deploy the Application and the ingress

With kustomize on kubectl apply the following

```sh
kubectl apply -k infra/todoapp/overlays/dev
kubectl apply -k infra/components/overlays/dev
```

**Configure Local Access**

To access the application in the browser, you need to configure your hosts file:

- For macOS/Linux

```sh
vim /etc/hosts
```

- For Windows: Open the file as Administrator

```sh
"C:\Windows\System32\drivers\etc\hosts"
```

Add the following line at last:

```text
127.0.0.1 todoapp.test
```

Then you can test on the browser at http://todoapp.test
