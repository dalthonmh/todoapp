terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Clave SSH compartida para todos los nodos
resource "digitalocean_ssh_key" "do_key" {
  name       = "do-ssh-key"
  public_key = file("~/.ssh/id_dalthonmh_digitalocean.pub")
}

# Controlplane
resource "digitalocean_droplet" "cp01" {
  name     = "cp01.unjbg.edu.pe"  
  region   = "nyc3"
  size     = "s-4vcpu-8gb"
  image    = "debian-13-x64"
  ssh_keys = [digitalocean_ssh_key.do_key.fingerprint]
}

# Worker 1
# resource "digitalocean_droplet" "wk01" {
#   name     = "wk01.unjbg.edu.pe"
#   region   = "nyc3"
#   size     = "s-4vcpu-8gb"
#   image    = "debian-13-x64"
#   ssh_keys = [digitalocean_ssh_key.do_key.fingerprint]
# }

output "cp01_ip" {
  value = digitalocean_droplet.cp01.ipv4_address
}

# output "wk01_ip" {
#   value = digitalocean_droplet.wk01.ipv4_address
# }
