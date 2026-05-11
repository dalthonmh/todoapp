# Kubernetes — Gateway API + Kustomize

Routing de la TodoApp usando **Gateway API** gestionado con **Kustomize**.

---

## Estructura

```
components/
├── base/
│   ├── gateway.yaml         # Gateway (listeners HTTP/HTTPS)
│   ├── httproute.yaml       # Reglas de ruteo
│   ├── cluster-issuer.yaml  # ClusterIssuer Let's Encrypt
│   └── kustomization.yaml
└── overlays/
    ├── dev/                 # hostname: todoapp.test  (HTTP)
    └── prod/                # hostname: dalthonmh.space (HTTP + HTTPS + TLS)
        └── certificate.yaml # Certificate para dalthonmh.space

todoapp/
├── base/                    # Deployments y Services
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
