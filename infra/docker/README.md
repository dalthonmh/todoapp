# ToDo App on Docker compose

This is a guide to install the project on ec2 server with terraform and docker compose
First we need create the ec2 with aws, we use the following command:

we will use debian image:
the terraform base was granted for KopiCloud Limited in https://github.com/KopiCloud/terraform-aws-debian-ec2-instance

Instalar docker:
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

curl -fsSL https://get.docker.com -o install-docker.sh
sudo sh install-docker.sh

docker run hello-world
