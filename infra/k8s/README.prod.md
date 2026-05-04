# Producción — TodoApp en Kubernetes

Guía para desplegar la TodoApp en un cluster bare-metal con HTTPS y certificado Let's Encrypt.

---

## Prerequisitos

- Cluster Kubernetes con acceso a internet
- Dominio apuntando a la IP pública del nodo (`dalthonmh.space → 174.138.67.1`)
- `kubectl` configurado
- Helm instalado

```sh
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
```

---

## 1. Instalar Gateway API CRDs

Los CRDs de Gateway API no vienen con Kubernetes ni con el Helm chart de Envoy Gateway. Deben instalarse primero:

```sh
#kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
# kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

# Verificar
# kubectl get crd | grep gateway.networking.k8s.io

helm template eg-crds oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.7.2 \
  --set crds.gatewayAPI.enabled=true \
  --set crds.gatewayAPI.channel=standard \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f -
```

---

## 2. Instalar Envoy Gateway

```sh
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.2 \
  -n envoy-gateway-system \
  --create-namespace \
  --skip-crds

kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available

# kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.7.2/quickstart.yaml -n default
```

Verificar:

```sh
# kubectl get gatewayclass
# NAME   CONTROLLER                                      ACCEPTED
# eg     gateway.envoyproxy.io/gatewayclass-controller   True
```

---

## 3. Instalar MetalLB

En bare-metal no hay LoadBalancer nativo. MetalLB asigna la IP pública al Service de Envoy para que el Gateway reciba un `ADDRESS`.

```sh
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
kubectl rollout status deployment/controller -n metallb-system
```

Configurar el pool con la IP pública del nodo:

```sh
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: public-pool
  namespace: metallb-system
spec:
  addresses:
    - 165.227.99.133/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
EOF
```

Verificar que el Service de Envoy tiene IP asignada: Verificar qeu external ip sea igual a la ip del nodo do

```sh
kubectl get svc -n envoy-gateway-system
# NAME                            TYPE           EXTERNAL-IP      PORT(S)
# envoy-prod-todoapp-gateway-...  LoadBalancer   174.138.67.1     80/TCP,443/TCP
```

---

git clone https://github.com/dalthonmh/todoapp.git

## 5. Desplegar microservicios

```sh
kubectl apply -k infra/k8s/todoapp/overlays/prod
```

Verificar que si se puede contectar a la aplicacion mediante el dominio

```sh
$ curl dalthonmh.space

<!DOCTYPE html>
<html lang="">
  <head>
    <meta charset="UTF-8">
    <link rel="icon" href="/favicon.ico">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vite App</title>
    <script type="module" crossorigin src="/assets/index-NdwtKuH7.js"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-ZBnmc1_k.css">
  </head>
  <body>
    <div id="app"></div>
  </body>
</html>
```

---

## 4. Instalar cert-manager

Instalar via Helm habilitando el soporte para Gateway API desde el inicio:

```sh
# 1. Actualizar el repositorio de Helm
helm repo add jetstack https://charts.jetstack.io --force-update

# 2. Instalar o actualizar cert-manager usando la nueva notación para Gateway API
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --set crds.enabled=true \
  --set config.enableGatewayAPI=true

# 3. Esperar a que el despliegue esté listo
kubectl rollout status deployment/cert-manager -n cert-manager
```

> El flag `config.enableGatewayAPI=true` es obligatorio para que cert-manager pueda resolver el challenge HTTP-01 a través del Gateway en lugar de un Ingress.

---

## 6. Desplegar Gateway (HTTP), rutas y certificado

> El Service `LoadBalancer` de Envoy y el pod proxy se crean automáticamente en este paso al detectar el recurso `Gateway`.
> El Gateway arranca **solo con el listener HTTP** para que Let's Encrypt pueda completar el challenge HTTP-01 antes de que el Secret TLS exista.

```sh
kubectl apply -k infra/k8s/components/overlays/prod
```

Esto crea en el namespace `prod`:

- `Gateway/todoapp-gateway` — listener HTTP :80
- `HTTPRoute/todoapp-route` — rutas hacia `auth`, `core` y `web`
- `ClusterIssuer/letsencrypt-prod` — conexión con Let's Encrypt (ACME HTTP-01)
- `Certificate/todoapp-prod-tls` — solicita el certificado para `dalthonmh.space`

---

## 7. Esperar el certificado y habilitar HTTPS

Esperar a que cert-manager complete el challenge HTTP-01 y emita el certificado (~1-2 min):

```sh
# Seguir el estado del certificado
kubectl get certificate -n prod -w
# READY=True indica que el Secret todoapp-prod-tls ya existe
```

Si se queda en `Ready=False`, revisar los eventos:

```sh
kubectl describe certificaterequest -n prod
kubectl get challenges -n prod
```

> **Requisito:** Let's Encrypt hace una petición HTTP al puerto 80 del dominio. El firewall del nodo debe permitir tráfico entrante en los puertos 80 y 443.

Cuando `READY=True`, agregar el listener HTTPS al Gateway:

```sh
kubectl patch gateway todoapp-gateway -n prod --type=json -p='
[{
  "op": "add",
  "path": "/spec/listeners/-",
  "value": {
    "name": "https",
    "protocol": "HTTPS",
    "port": 443,
    "hostname": "dalthonmh.space",
    "tls": {
      "mode": "Terminate",
      "certificateRefs": [{"name": "todoapp-prod-tls", "kind": "Secret"}]
    },
    "allowedRoutes": {"namespaces": {"from": "Same"}}
  }
}]'
```

Verificar que el listener HTTPS queda `PROGRAMMED=True`:

```sh
kubectl get gateway todoapp-gateway -n prod -o jsonpath='{.status.listeners[*].conditions}'
# o más legible:
kubectl describe gateway todoapp-gateway -n prod | grep -A5 'Listener Statuses'
```

---

## 8. Probar

```sh
curl https://dalthonmh.space/
curl https://dalthonmh.space/api/auth/health
curl https://dalthonmh.space/api/tasks
```

Para ver motivo de fallo

# Obtén el nombre exacto del challenge

kubectl get challenges -n prod

# Describe el challenge para ver los eventos y el mensaje de error

kubectl describe challenge <nombre-del-challenge> -n prod
