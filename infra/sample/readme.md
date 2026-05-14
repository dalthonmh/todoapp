# Levantar un deployment de posgresql

Creamos el secret

```bash
kubectl create secret generic postgresql-secret --from-literal=POSTGRES_PASSWORD=SECRET123
```
