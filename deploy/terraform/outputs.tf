output "server_ip" {
  value = vultr_instance.likho.main_ip
}

output "server_ipv6" {
  value = vultr_instance.likho.v6_main_ip
}

output "nameservers" {
  description = "Set these at the registrar where you bought the domain."
  value       = ["ns1.vultr.com", "ns2.vultr.com"]
}

output "ssh_allowed_from" {
  value = local.ssh_cidrs
}

output "urls" {
  value = {
    website = "https://${var.domain}"
    api     = "https://${local.api_domain}"
    admin   = "deploy/admin-tunnel.sh, then http://localhost:8080/admin/"
  }
}

# Break-glass only: the Vultr web console (View Console) accepts it when SSH
# is lost. SSH itself never takes a password.
output "root_password" {
  value     = vultr_instance.likho.default_password
  sensitive = true
}
