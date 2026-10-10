output "server_ip" {
  value = vultr_instance.likho.main_ip
}

output "server_ipv6" {
  value = vultr_instance.likho.v6_main_ip
}

output "nameservers" {
  description = "With dns_on_vultr: set these at the registrar where you bought the domain."
  value       = var.dns_on_vultr ? ["ns1.vultr.com", "ns2.vultr.com"] : []
}

output "dns_records" {
  description = "Without dns_on_vultr: add these where the domain's DNS is (e.g. Vercel → Domains → DNS records)."
  value = var.dns_on_vultr ? [] : flatten([for n in local.dns_names : [
    { name = n == "" ? "@" : n, type = "A", value = vultr_instance.likho.main_ip },
    { name = n == "" ? "@" : n, type = "AAAA", value = vultr_instance.likho.v6_main_ip },
  ]])
}

output "ssh_allowed_from" {
  value = local.ssh_cidrs
}

output "urls" {
  value = {
    website = var.website_on_server ? "https://${var.domain}" : "not on this server"
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
