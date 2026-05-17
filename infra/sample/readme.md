# Levantar bases de datos

## 1. Base de datos posgresql:

Creamos el secret

```bash
kubectl create secret generic postgresql-secret --from-literal=POSTGRES_PASSWORD=SECRET123
```

## 2. Base de datos mysql:

Secret:

```bash
kubectl create secret generic mysql-secret \
  --from-literal=MYSQL_PASSWORD=admin123 \
  --from-literal=MYSQL_ROOT_PASSWORD=root123
```
