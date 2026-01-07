# ToDo-APP in Kubernetes

Aplicacion creada para probar la infraestructura en la nube

## Instalación

### Entorno local

Usaremos [kind](https://kind.sigs.k8s.io/) como cluster local de kubernetes usando docker. Iniciamos docker y creamos un cluster con 3 nodos con kind

```sh
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: multinode
nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP
  - role: worker
  - role: worker
EOF
```

> Nota: Si quieres eliminar clusters de kind antes iniciar puedes ejecutar:
>
> - `kind delete cluster --name multinode`
> - `kind delete cluster -A `

Instalamos un ingress, para este ejemplo usaremos [Ingress nginx](https://github.com/kubernetes/ingress-nginx) de Kubernetes

```sh
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```
