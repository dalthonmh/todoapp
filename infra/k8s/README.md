# Kubernetes — Gateway API + Kustomize

Routing de la TodoApp usando **Gateway API** (reemplazo oficial del Ingress) gestionado con **Kustomize**.

---

## Estructura

```
components/
├── base/
│   ├── gateway.yaml       # Entry point (listeners HTTP/HTTPS)
│   ├── httproute.yaml     # Reglas de ruteo hacia los servicios
│   └── kustomization.yaml
└── overlays/
    ├── dev/               # hostname: todoapp.test
    └── prod/              # hostname: dalthonmh.space + TLS

todoapp/
├── base/                  # Deployments y Services de la app
└── overlays/
    ├── dev/
    └── prod/
```

### Rutas

| Path         | Servicio | Puerto |
| ------------ | -------- | ------ |
| `/api/auth`  | `auth`   | 8080   |
| `/api/tasks` | `core`   | 3000   |
| `/`          | `web`    | 80     |

---

## 1. Instalar Kustomize

```sh
# macOS
brew install kustomize

# Linux
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

> También disponible en `kubectl` sin instalación extra: `kubectl apply -k <path>`

---

## 2. Instalar Gateway API CRDs

Los CRDs no vienen con Kubernetes, hay que instalarlos antes de aplicar cualquier `Gateway` o `HTTPRoute`.

```sh
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

---

## 3. Instalar NGINX Gateway Fabric

```sh
# CRDs del controlador
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.4.0/deploy/crds.yaml

# Controlador — local (NodePort)
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.4.0/deploy/nodeport/deploy.yaml

# Controlador — cloud (LoadBalancer)
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.4.0/deploy/default/deploy.yaml
```

Verificar:

```sh
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
```

---

## 4. Desplegar con Kustomize

```sh
# Ver manifiestos renderizados (sin aplicar)
kustomize build infra/k8s/components/overlays/dev

# Aplicar — desarrollo
kubectl apply -k infra/k8s/todoapp/overlays/dev
kubectl apply -k infra/k8s/components/overlays/dev

# Aplicar — producción
kubectl apply -k infra/k8s/todoapp/overlays/prod
kubectl apply -k infra/k8s/components/overlays/prod
```

---

## 5. Verificar

```sh
kubectl get gateway -n dev
kubectl get httproute -n dev
kubectl describe httproute todoapp-route -n dev
```

Para clusters locales, agregar el hostname a `/etc/hosts`:

```sh
echo "127.0.0.1 todoapp.test" | sudo tee -a /etc/hosts

curl http://todoapp.test/api/auth/health
curl http://todoapp.test/
```

---

## 6. TLS con cert-manager (prod)

```sh
# Instalar cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
```

Crear un `ClusterIssuer` apuntando a Let's Encrypt y agregar la anotación al Gateway prod mediante un patch en el overlay:

```yaml
- op: add
  path: /metadata/annotations/cert-manager.io~1cluster-issuer
  value: letsencrypt-prod
```

cert-manager creará automáticamente el Secret `todoapp-prod-tls` referenciado en el listener HTTPS del Gateway.
