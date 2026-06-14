# Environments: prod vs stage

We now have two separate environments managed via ArgoCD + Kustomize:

| Environment | Domain / Hostname                        | TLS / HTTPS      | Purpose                              |
|-------------|------------------------------------------|------------------|--------------------------------------|
| **prod**    | `todoapp.store`                          | Yes (cert-manager + Let's Encrypt) | Real production-like deployment     |
| **stage**   | `todoapp.159.203.120.126.nip.io`         | No (HTTP only)   | Quick testing / iteration on the VPS |

- **prod** now owns the real custom domain + full TLS setup.
- **stage** uses the convenient nip.io hostname (no DNS changes needed) for fast development and testing before going to the real domain.

This separation keeps the quick feedback loop in `stage` while `prod` is the one that serves `https://todoapp.store`.

## Goals

- Use `stage` for most daily work (fast deploys via nip.io).
- Only promote / use `prod` when you want the real domain with valid certificates.
- Both are fully declarative and deployed through ArgoCD (App of Apps pattern).
- The old manual steps from `ingress_add.md` are replaced by the declarative overlays below.

## Prerequisites

- The domain `todoapp.store` points to your Droplet's public IP (A record).
- Ports **80 and 443** are open in the DigitalOcean firewall for the Droplet.
- k3s + Traefik running (default on k3s).
- ArgoCD + the `todoapp` project already set up.

## Folder structure (current)

```
infra/k8s/
  cert-manager/prod/          # ClusterIssuers (used only by real prod)
  todoapp/overlays/{prod,stage}
  components/overlays/{prod,stage}

infra/argocd/
  applications/{prod,stage}/
  bootstrap/app-of-apps-{prod,stage}.yaml
```

## Deploying

**1. Install cert-manager (one time):**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
```

**2. Set your email** in `infra/k8s/cert-manager/prod/cluster-issuer.yaml`

**3. Deploy stage (quick nip.io testing):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-stage.yaml
```

Access: `http://todoapp.159.203.120.126.nip.io`

**4. Deploy prod (real domain + TLS):**

```bash
kubectl apply -f infra/argocd/bootstrap/app-of-apps-prod.yaml
```

Access: `https://todoapp.store` (wait for certificate to be Ready)

You can deploy both at the same time.

## Making changes

- Change real domain / TLS → edit `infra/k8s/components/overlays/prod/kustomization.yaml`
- Change nip.io for stage → edit `infra/k8s/components/overlays/stage/kustomization.yaml`
- Change email or issuers → edit `infra/k8s/cert-manager/prod/cluster-issuer.yaml`

Commit → push → sync the relevant `components-*` app in ArgoCD.

## Notes

- Start with the `letsencrypt-staging` issuer in prod if you're testing (change the annotation and sync).
- Once stable, switch to `letsencrypt-prod`.
- Both prod and stage workloads currently use the same base manifests. You can add environment-specific customizations in their respective overlays later.
- The old imperative steps in `ingress_add.md` are no longer needed — everything is now in the Kustomize overlays managed by ArgoCD.
