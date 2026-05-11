# Droplet de Digital Ocean con Terraform

Requisitos:

1. Tener instalado Terraform

```bash
terraform -v
# Terraform v1.14.3
# on darwin_amd64
```

2. Obtener el token de Digital Ocean

Entramos a la parte izquierda donde dice "ACCOUNT" > "API" > "Create A New Personal Access Token"
Completamos el nombre de token "terraform2" y en los scopes seleccionamos "droplet" y "ssh_key" con los 5 scopes: completamos con los defaults scopes

Lo guardamos como variable de entorno en macos

```bash
export TF_VAR_do_token="dop_v1_..."
```

3. Revisar los archivos

Tenemos que revisar la configuracion de los archivos e iniciar con terraform

```bash
terraform init
terraform plan
terraform apply
```

La contraseña sera enviada al correo electronico.

4. Generamos el ssh key

```bash
ssh-keygen -t ed25519 -C "do-droplet"
# id_dalthonmh_digitalocean
```

entramos al droplet con ssh -i

```bash
ssh -i id_dalthonmh_digitalocean root@138.197.25.128
```
