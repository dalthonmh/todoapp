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

## 2. Instalar MetalLB

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
    - 174.138.67.1/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
EOF
```

Verificar que el Service de Envoy tiene IP asignada:

```sh
kubectl get svc -n envoy-gateway-system
# NAME                            TYPE           EXTERNAL-IP      PORT(S)
# envoy-prod-todoapp-gateway-...  LoadBalancer   174.138.67.1     80/TCP,443/TCP
```

---

## 3. Instalar cert-manager

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml
kubectl rollout status deployment/cert-manager -n cert-manager
```

---

## 4. Desplegar microservicios

```sh
kubectl apply -k infra/k8s/todoapp/overlays/prod
```

---

## 5. Desplegar Gateway, rutas y certificado

```sh
kubectl apply -k infra/k8s/components/overlays/prod
```

Esto crea en el namespace `prod`:

- `Gateway/todoapp-gateway` — listener HTTP :80 + HTTPS :443 con TLS termination
- `HTTPRoute/todoapp-route` — rutas hacia `auth`, `core` y `web`
- `ClusterIssuer/letsencrypt-prod` — conexión con Let's Encrypt (ACME HTTP-01)
- `Certificate/todoapp-prod-tls` — solicita el certificado para `dalthonmh.space`

---

## 6. Verificar el certificado y el Gateway

```sh
# Seguir el estado del certificado (tarda ~1-2 min)
kubectl get certificate -n prod
kubectl describe certificate todoapp-prod-tls -n prod

# Cuando Ready=True el Secret existe
kubectl get secret todoapp-prod-tls -n prod

# El Gateway debe pasar a PROGRAMMED=True
kubectl get gateway -n prod
# NAME              CLASS   ADDRESS         PROGRAMMED   AGE
# todoapp-gateway   eg      174.138.67.1    True         2m
```

Si el Certificate se queda en `Ready=False`, revisar los eventos:

```sh
kubectl describe certificaterequest -n prod
# Buscar: "Waiting for HTTP-01 challenge" o errores de conexión
```

> **Requisito del challenge HTTP-01:** Let's Encrypt hace una petición HTTP al puerto 80 del dominio. El firewall del nodo debe permitir tráfico entrante en los puertos 80 y 443.

---

## 7. Probar

```sh
curl https://dalthonmh.space/
curl https://dalthonmh.space/api/auth/health
curl https://dalthonmh.space/api/tasks
```
