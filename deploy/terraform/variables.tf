variable "domain" {
  description = "The domain you bought, without www (e.g. likho.io). The API is served at api.<domain>; the website at it and www when website_on_server."
  type        = string
}

variable "website_on_server" {
  description = "Serve the website (landing/) from this server too. false = it lives elsewhere (e.g. Vercel) and the server only runs the API."
  type        = bool
  default     = false
}

variable "dns_on_vultr" {
  description = "Vultr runs the domain's DNS (nameservers ns1.vultr.com, ns2.vultr.com). false = the DNS stays where it is (e.g. Vercel): add the records in output dns_records there."
  type        = bool
  default     = false
}

variable "region" {
  description = "Vultr region id. sgp = Singapore, fra = Frankfurt, bom = Mumbai, del = Delhi. Pick the one with the lowest ping from Pakistan (see README)."
  type        = string
  default     = "sgp"
}

variable "plan" {
  description = "Vultr plan id. vc2-1c-2gb (1 CPU, 2 GB) fits Likho's capped containers; vc2-2c-4gb leaves room to grow."
  type        = string
  default     = "vc2-1c-2gb"
}

variable "ssh_public_key_path" {
  description = "The public half of the deploy key (ssh-keygen -t ed25519 -f ~/.ssh/likho_deploy)."
  type        = string
  default     = "~/.ssh/likho_deploy.pub"
}

variable "ssh_allowed_cidrs" {
  description = "Who may open SSH (IPv4 CIDRs). Empty = only the IP of the computer running terraform apply right now."
  type        = list(string)
  default     = []
}

variable "letsencrypt_email" {
  description = "Let's Encrypt writes here before a certificate expires (it renews by itself)."
  type        = string
}

variable "google_client_ids" {
  description = "Google OAuth client IDs the API accepts (iOS, Android, Web), comma separated. Public values, not secrets."
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "The first owner of the admin panel. The password is generated on the server (see README)."
  type        = string
}

variable "ddos_protection" {
  description = "Vultr's paid DDoS protection (about 10 USD a month extra)."
  type        = bool
  default     = false
}
