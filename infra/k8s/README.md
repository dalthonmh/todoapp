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

## 2. Instalar Envoy Gateway

Instalar Helm:

```sh
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
```

Instalar Envoy Gateway (incluye el GatewayClass `eg`):
Los CRDs no vienen con Kubernetes, hay que instalarlos antes de aplicar cualquier `Gateway` o `HTTPRoute`.

```sh
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.2 \
  -n envoy-gateway-system \
  --create-namespace

kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available

kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.7.2/quickstart.yaml -n default
```

Verificar:

```sh
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
# NAME   CONTROLLER                                      ACCEPTED
# eg     gateway.envoyproxy.io/gatewayclass-controller   True
```

> El campo `ACCEPTED` puede aparecer como `Unknown` unos segundos mientras el controlador arranca. Esperar a que sea `True`.

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

Para clusters locales, obtener la IP del Gateway y agregar el hostname a `/etc/hosts`:

```sh
kubectl get svc -n envoy-gateway-system

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
