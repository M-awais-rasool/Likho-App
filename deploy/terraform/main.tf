# Likho's server on Vultr: one Ubuntu machine behind a Vultr firewall, its
# DNS, and daily backups. Everything the server runs is set up by
# cloud-init.yaml.tftpl on first boot and by ../deploy.sh afterwards.
#
#   export VULTR_API_KEY=...        # never written to a file
#   terraform init && terraform apply
#
# See ../README.md for the whole walk-through.

provider "vultr" {} # reads VULTR_API_KEY

locals {
  api_domain = "api.${var.domain}"
  # SSH only from the given networks, or else from this computer's IP now
  ssh_cidrs = length(var.ssh_allowed_cidrs) > 0 ? var.ssh_allowed_cidrs : ["${chomp(data.http.my_ip.response_body)}/32"]
}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = ["Ubuntu 24.04 LTS x64"]
  }
}

resource "vultr_ssh_key" "deploy" {
  name    = "likho-deploy"
  ssh_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# ------------------------------------------------------------------ firewall
# Vultr drops everything else before it reaches the machine (the machine's
# own ufw does the same again).
resource "vultr_firewall_group" "likho" {
  description = "likho"
}

resource "vultr_firewall_rule" "ssh" {
  for_each          = toset(local.ssh_cidrs)
  firewall_group_id = vultr_firewall_group.likho.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = split("/", each.value)[0]
  subnet_size       = tonumber(split("/", each.value)[1])
  port              = "22"
  notes             = "ssh"
}

resource "vultr_firewall_rule" "web" {
  for_each = {
    "v4-80"  = ["v4", "0.0.0.0", 0, "80"]
    "v4-443" = ["v4", "0.0.0.0", 0, "443"]
    "v6-80"  = ["v6", "::", 0, "80"]
    "v6-443" = ["v6", "::", 0, "443"]
  }
  firewall_group_id = vultr_firewall_group.likho.id
  protocol          = "tcp"
  ip_type           = each.value[0]
  subnet            = each.value[1]
  subnet_size       = each.value[2]
  port              = each.value[3]
  notes             = "web"
}

# ------------------------------------------------------------------ server
resource "vultr_instance" "likho" {
  label             = "likho"
  hostname          = "likho"
  region            = var.region
  plan              = var.plan
  os_id             = data.vultr_os.ubuntu.id
  enable_ipv6       = true
  ssh_key_ids       = [vultr_ssh_key.deploy.id]
  firewall_group_id = vultr_firewall_group.likho.id
  ddos_protection   = var.ddos_protection
  activation_email  = false # the email would carry the root password
  tags              = ["likho"]

  # a copy of the whole disk every day at 21:00 UTC (02:00 in Pakistan),
  # half an hour after the server's own database dump
  backups = "enabled"
  backups_schedule {
    type = "daily"
    hour = 21
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ssh_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  lifecycle {
    # the database lives on this disk: never replace or delete it by accident
    prevent_destroy = true
    ignore_changes  = [user_data, os_id, ssh_key_ids]
  }
}

# ------------------------------------------------------------------ DNS
# Only with dns_on_vultr: Vultr runs the domain's DNS (set the registrar's
# nameservers to ns1.vultr.com and ns2.vultr.com). Otherwise the DNS stays
# where it is (e.g. Vercel) and you add the records in output "dns_records"
# there.
locals {
  dns_names = var.website_on_server ? ["", "www", "api"] : ["api"]
}

resource "vultr_dns_domain" "likho" {
  count  = var.dns_on_vultr ? 1 : 0
  domain = var.domain
}

resource "vultr_dns_record" "a" {
  for_each = var.dns_on_vultr ? toset(local.dns_names) : toset([])
  domain   = vultr_dns_domain.likho[0].id
  name     = each.value
  type     = "A"
  data     = vultr_instance.likho.main_ip
  ttl      = 300
}

resource "vultr_dns_record" "aaaa" {
  for_each = var.dns_on_vultr ? toset(local.dns_names) : toset([])
  domain   = vultr_dns_domain.likho[0].id
  name     = each.value
  type     = "AAAA"
  data     = vultr_instance.likho.v6_main_ip
  ttl      = 300
}

# only Let's Encrypt may issue certificates for the domain
resource "vultr_dns_record" "caa" {
  count  = var.dns_on_vultr ? 1 : 0
  domain = vultr_dns_domain.likho[0].id
  name   = ""
  type   = "CAA"
  data   = "0 issue \"letsencrypt.org\""
  ttl    = 3600
}

# the domain sends no email: receivers reject mail that pretends to be from
# it (remove these two if you set up email on the domain)
resource "vultr_dns_record" "spf" {
  count  = var.dns_on_vultr ? 1 : 0
  domain = vultr_dns_domain.likho[0].id
  name   = ""
  type   = "TXT"
  data   = "\"v=spf1 -all\""
  ttl    = 3600
}

resource "vultr_dns_record" "dmarc" {
  count  = var.dns_on_vultr ? 1 : 0
  domain = vultr_dns_domain.likho[0].id
  name   = "_dmarc"
  type   = "TXT"
  data   = "\"v=DMARC1; p=reject; adkim=s; aspf=s\""
  ttl    = 3600
}

# ------------------------------------------------------------------ for deploy.sh
# Not secret: where the server is and which domains it serves.
resource "local_file" "server_env" {
  filename        = "${path.module}/../server.env"
  file_permission = "0600"
  content         = <<-EOT
    # Written by terraform (deploy/terraform). Read by deploy.sh.
    SERVER_IP=${vultr_instance.likho.main_ip}
    SSH_USER=deploy
    SSH_KEY=${replace(pathexpand(var.ssh_public_key_path), "/\\.pub$/", "")}
    API_DOMAIN=${local.api_domain}
    SITE_DOMAIN=${var.website_on_server ? var.domain : ""}
    LETSENCRYPT_EMAIL=${var.letsencrypt_email}
    GOOGLE_CLIENT_IDS=${var.google_client_ids}
    ADMIN_EMAIL=${var.admin_email}
  EOT
}
