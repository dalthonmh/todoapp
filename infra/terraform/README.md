# DigitalOcean Droplet with Terraform

This Terraform configuration provisions a virtual machine (Droplet) on DigitalOcean. It is designed as a simple way to get a VPS where you can later install Kubernetes (for example, k3s) and deploy the TodoApp.

## What It Creates

- 1 Droplet named `cp01` (control plane)
  - Region: `nyc3`
  - Size: `s-4vcpu-8gb` (4 vCPU, 8 GB RAM)
  - OS: Debian 13
  - SSH key attached for secure access
- Uploads your SSH public key to DigitalOcean
- Outputs the public IP address of the Droplet

> **Note**: A second worker node (`wk01`) is defined in `main.tf` but is currently commented out.

---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) installed
- A DigitalOcean account
- A DigitalOcean Personal Access Token with permissions to manage Droplets and SSH keys

---

## Step-by-Step Instructions

### 1. Install Terraform

Verify that Terraform is installed:

```bash
terraform -v
```

If not installed, download it from the official website.

### 2. Create a DigitalOcean API Token

1. Log in to the [DigitalOcean Control Panel](https://cloud.digitalocean.com/).
2. Go to the left sidebar → **API**.
3. Click **Generate New Token**.
4. Give it a name (e.g. `terraform-todoapp`).
5. Under **Scopes**, select at minimum:
   - **Droplet** (Write access)
   - **SSH Key** (Write access)
6. Click **Generate Token**.
7. **Copy the token immediately** — you won’t be able to see it again.

### 3. Set the Token as an Environment Variable

Export the token so Terraform can use it:

```bash
export TF_VAR_do_token="dop_v1_your_token_here"
```

> **Tip**: Add this line to your `~/.zshrc` or `~/.bashrc` so you don’t have to export it every time.

### 4. Prepare Your SSH Key

Terraform is configured to use a specific SSH key located at:

```
~/.ssh/id_dalthonmh_digitalocean.pub
```

#### Option A: Generate a new key with the expected name (recommended for first time)

```bash
ssh-keygen -t ed25519 -C "digitalocean-todoapp" -f ~/.ssh/id_dalthonmh_digitalocean
```

This will create:

- Private key: `~/.ssh/id_dalthonmh_digitalocean`
- Public key: `~/.ssh/id_dalthonmh_digitalocean.pub`

#### Option B: Use your existing key

If you already have an SSH key you want to use, edit the file `main.tf` and change this line:

```hcl
public_key = file("~/.ssh/id_dalthonmh_digitalocean.pub")
```

to point to your actual public key (for example `~/.ssh/id_ed25519.pub`).

### 5. Initialize and Apply Terraform

Navigate to the terraform directory:

```bash
cd infra/terraform
```

Initialize Terraform (downloads the DigitalOcean provider):

```bash
terraform init
```

Review what will be created:

```bash
terraform plan
```

Create the resources:

```bash
terraform apply
```

Type `yes` when prompted.

After it finishes, you will see the output with the Droplet’s IP address, for example:

```
cp01_ip = "123.45.67.89"
```

### 6. Connect to the Droplet via SSH

Use the private key you generated:

```bash
ssh -i ~/.ssh/id_dalthonmh_digitalocean root@<YOUR_DROPLET_IP>
```

Once connected, you can install k3s or any other software you need.

## Cleanup

When you no longer need the server:

```bash
terraform destroy
```

Confirm with `yes`. This will permanently delete the Droplet.

For detailed Kubernetes + TodoApp deployment instructions, see [infra/k8s/README.md](../k8s/README.md).
