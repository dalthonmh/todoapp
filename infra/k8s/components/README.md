# Instalacion de ingress class

Usaremos los siguientes pasos:

## Agregamos el repositorio oficial

```sh
helm repo add traefik https://traefik.github.io/charts
helm repo update
kubectl create namespace traefik
```

## Archivo de valores recomendados

Instalamos

cd traefik

```sh

helm install traefik traefik/traefik \
  --namespace traefik \
  --values traefik-values.yaml
```

Verificamos la instalacion

```sh
kubectl get pods -n traefik
kubectl get svc -n traefik
kubectl get ingressclass
```

Dashboard de kind

```sh
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: dashboard
  namespace: traefik
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`localhost`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))
    kind: Rule
    services:
    - kind: TraefikService
      name: api@internal
```

Lo aplicamos

```sh
kubectl apply -f dashboard.yaml
```

Ahora abre en tu navegador:

kubectl port-forward -n traefik deployment/traefik 9000:9000

Dashboard: http://localhost:9000/dashboard/
