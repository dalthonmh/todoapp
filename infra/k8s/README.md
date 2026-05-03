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

Instalar Envoy Gateway (el chart incluye los Gateway API CRDs y crea el GatewayClass `eg`):

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
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
# NAME   CONTROLLER                                      ACCEPTED
# eg     gateway.envoyproxy.io/gatewayclass-controller   True
```

> El campo `ACCEPTED` puede aparecer como `Unknown` unos segundos mientras el controlador arranca. Esperar a que sea `True`.

---

## 3. Desplegar los microservicios

```sh
# Desarrollo
kubectl apply -k infra/k8s/todoapp/overlays/dev

# Producción
kubectl apply -k infra/k8s/todoapp/overlays/prod
```

---

## 4. Desplegar el Gateway y las rutas

```sh
# Ver manifiestos renderizados (sin aplicar)
kustomize build infra/k8s/components/overlays/prod

# Desarrollo
kubectl apply -k infra/k8s/components/overlays/dev

# Producción
kubectl apply -k infra/k8s/components/overlays/prod
```

Esto crea en el namespace correspondiente:

- `Gateway/todoapp-gateway` — listener HTTP (dev) o HTTP+HTTPS (prod)
- `HTTPRoute/todoapp-route` — reglas de ruteo hacia `auth`, `core` y `web`

Envoy Gateway detecta el Gateway y provisiona automáticamente un pod Envoy proxy. Verificar que `PROGRAMMED=True`:

```sh
kubectl get gateway -n prod
# NAME               CLASS   ADDRESS        PROGRAMMED   AGE
# todoapp-gateway    eg      203.0.113.10   True         1m
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
