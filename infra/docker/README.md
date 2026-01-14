# ToDo App on Docker compose

This is a guide to install the project on ec2 server with terraform and docker compose
First we need create the ec2 with aws, we use the following command:

we will use debian image:
the terraform base was granted for KopiCloud Limited in https://github.com/KopiCloud/terraform-aws-debian-ec2-instance

## Instalar docker:

```sh
sudo mkdir -p /usr/local/docker
cd /usr/local/docker
sudo curl -fsSL https://get.docker.com -o install-docker.sh
sudo sh install-docker.sh
sudo usermod -aG docker $USER && newgrp docker

docker run hello-world
```

## Ejecutar comandos

```sh
sudo mkdir -p $HOME/todoapp
cd $HOME/todoapp
```

Nos traemos los archivos de configuracion

```sh
sudo apt install zip unzip
sudo wget https://github.com/dalthonmh/todoapp/releases/download/v1.0.0/todoapp-docker.zip
unzip todoapp-docker.zip
```

editamos las variables de entorno

```sh
sudo cp .env.sample .env
```

Iniciamos las aplicaciones

```sh
docker compose up -d
```

Configurar ngin
