# ToDo-APP in Kubernetes

Aplicacion creada para probar la infraestructura en la nube

## Instalación

### Clonar repositorios

Todos los repositorios pueden ser descargados desde github:

```sh
git clone https://github.com/dalthonmh/todoapp-auth
git clone https://github.com/dalthonmh/todoapp-core
git clone https://github.com/dalthonmh/todoapp-web
```

Para iniciar cada proyecto entramos dentro de cada uno y seguimos sus pasos de instalación.

## Instalación con Kubernetes

### Entorno local

Usaremos [kind](https://kind.sigs.k8s.io/) como cluster local de kubernetes usando docker. Iniciamos Docker y creamos un cluster con Kind.

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

> Nota: Si quieres eliminar clusters de kind antes iniciar puedes ejecutar: `kind delete cluster --name kind`

Instalamos un ingress class, para este ejemplo usaremos [Ingress nginx](https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/kind/deploy.yaml) de Kubernetes

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

> Nota: si has creado un cluster con mas de un nodo, asegurate de que el pod ingress-nginx-controller se ejecute en el controlplane.

Iniciaremos las aplicaciones con kustomize en el entorno de desarrollo:

```sh
kubectl apply -k infra/todoapp/overlays/dev
```

Despues instalamos el ingress

```sh
kubectl apply -k infra/components/overlays/dev
```

Configuramos los /etc/hosts para que podamos verlo en el navegador:

```sh
vim /etc/hosts
```

Agregamos lo siguiente:

```text
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1       localhost
::1             localhost
127.0.0.1 todoapp.test
```

Para windows:

```sh
vim "C:\Windows\System32\drivers\etc\hosts"
127.0.0.1   todoapp.test
```
