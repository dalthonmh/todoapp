# Deploy ToDo-App with Docker compose

This is a guide to install the project on AWS EC2 server with terraform and docker compose.
First we need create the ec2 instance in AWS, you could use this guide: https://github.com/dalthonmh/terraform-aws-ec2

## Install Docker:

Note: These scripts are designed for Debian-based OS

```sh
sudo mkdir -p /usr/local/docker && cd /usr/local/docker
sudo curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

docker run hello-world
```

## Execute the commands

Download configuration files

```sh
sudo mkdir -p $HOME/todoapp && cd $HOME/todoapp
sudo apt install zip unzip
sudo wget https://github.com/dalthonmh/todoapp/releases/download/v1.0.0/todoapp-docker.zip
sudo unzip todoapp-docker.zip
```

Start the app

```sh
sudo cp .env.sample .env
docker compose up -d
```
