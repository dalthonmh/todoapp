# Desarrollo — TodoApp en Kubernetes

Guía para desplegar la TodoApp en un cluster local (kind / minikube / kubeadm) con HTTP simple.

---

## Prerequisitos

- Cluster Kubernetes corriendo
- `kubectl` configurado
- Kustomize instalado

```sh
# macOS
brew install kustomize

# Linux
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

---

## 1. Instalar Envoy Gateway

```sh
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.2 \
  -n envoy-gateway-system \
  --create-namespace

kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available
```

Verificar:

```sh
kubectl get gatewayclass
# NAME   CONTROLLER                                      ACCEPTED
# eg     gateway.envoyproxy.io/gatewayclass-controller   True
```

---

## 2. Desplegar microservicios

```sh
kubectl apply -k infra/k8s/todoapp/overlays/dev
```

---

## 3. Desplegar Gateway y rutas

```sh
kubectl apply -k infra/k8s/components/overlays/dev
```

Esto crea en el namespace `dev`:

- `Gateway/todoapp-gateway` — listener HTTP en puerto 80, hostname `todoapp.test`
- `HTTPRoute/todoapp-route` — rutas hacia `auth`, `core` y `web`

---

## 4. Verificar

```sh
kubectl get gateway -n dev
kubectl get httproute -n dev
```

Agregar el hostname a `/etc/hosts` apuntando a la IP del nodo:

```sh
# Obtener IP del Service de Envoy
kubectl get svc -n envoy-gateway-system

echo "127.0.0.1 todoapp.test" | sudo tee -a /etc/hosts
```

Probar:

```sh
curl http://todoapp.test/
curl http://todoapp.test/api/auth/health
curl http://todoapp.test/api/tasks
```
