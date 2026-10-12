# Deploying Likho (Vultr + Terraform)

One Ubuntu 24.04 server on Vultr runs the API. Likho's domain is `likho.io`; its website
(`landing/`, privacy and deletion pages) and its DNS are on Vercel.

| Address | What | Served by |
|---|---|---|
| `https://api.likho.io` | the API the app talks to, and `/media/` | nginx → API container (Vultr) |
| `https://likho.io` (and `www.`) | the website | Vercel |
| `https://admin.likho.io/admin/` | the admin panel (password + authenticator code) | nginx → API container (Vultr) |

Terraform (`terraform/`) creates the server, its firewall and its daily backups. `deploy.sh` puts
Likho on it. Both run from your computer. (With `website_on_server = true` the server serves the
website too, and with `dns_on_vultr = true` Vultr runs the DNS: then set the registrar's
nameservers to `ns1.vultr.com` and `ns2.vultr.com` instead of adding records by hand.)

## What to get first

1. **A Vultr account.** Turn on two-factor login (Account → Authentication) and add a payment
   method. Do not create a server in the dashboard: Terraform creates it.
2. **A Vultr API key.** Account → API → Enable API. Under **Access Control**, allow only your own
   IP. Put the key in a file only you can read, not in the repository and not in a chat:

   ```bash
   mkdir -p ~/.config/likho && printf 'export VULTR_API_KEY=%s\n' 'PASTE-KEY-HERE' > ~/.config/likho/vultr.env && chmod 600 ~/.config/likho/vultr.env
   ```

3. **The domain** (`likho.io`, bought at Name.com, DNS on Vercel). Turn on two-factor login, the
   registrar lock and WHOIS privacy at the registrar, and two-factor login on Vercel.
4. **A deploy SSH key with a passphrase** (used for nothing else):

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/likho_deploy -C likho-deploy
   ```

Cost: the 1 CPU / 2 GB plan is about 10 USD a month, and daily backups add 20% (about 2 USD).

## First deploy

```bash
cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars      # fill in the domain and emails
source ~/.config/likho/vultr.env
terraform init
terraform apply
```

Then:

1. In Vercel → the `likho.io` domain → DNS Records, add the records from
   `terraform output dns_records`: `api` A (the server's IPv4) and `api` AAAA (its IPv6). DNS can
   take from minutes to an hour.
2. Run `deploy/deploy.sh` from the repository root. It waits for the server's first-boot setup,
   then sends everything and starts it. On the first run it prints the admin panel password once:
   save it, then change it in the panel. If DNS does not point to the server yet, it says so; run
   it again later.

Every deploy after that is just `deploy/deploy.sh` (or `deploy/deploy.sh media` for new pictures
and recordings only).

Running `deploy.sh` accepts the Let's Encrypt subscriber agreement for the certificate.

## Google Play Billing (Likho Plus)

1. Put the Google Play service account's JSON key at `~/.config/likho/play-service-account.json`
   (`chmod 600`). `deploy.sh` sends it; `server-setup.sh` installs it in `/srv/likho/secrets/`,
   readable only by the API's user, and sets `PLAY_SERVICE_ACCOUNT_FILE`.
2. The first deploy makes `PLAY_NOTIFY_KEY` and prints the push URL
   (`https://api.<domain>/v1/play/notifications?key=…`): it is the Pub/Sub push subscription's
   endpoint. Show it again with `sudo grep PLAY_NOTIFY_KEY /srv/likho/src/deploy/.env` on the server.
   nginx keeps that URL out of its access log.

## Every day

| Task | Command |
|---|---|
| Deploy a change | `deploy/deploy.sh` |
| Send new media only | `deploy/deploy.sh media` |
| Open the admin panel | <https://admin.likho.io/admin/> (or `deploy/admin-tunnel.sh`, then <http://localhost:18080/admin/>) |
| An admin lost their phone | an owner: Team → Reset 2-step. The last owner: on the server, `cd /srv/likho/src/deploy && docker compose exec api /likho-api admin-reset-2fa <email>` |
| Your home IP changed (SSH refused) | `source ~/.config/likho/vultr.env && terraform -chdir=deploy/terraform apply` |
| Log in to the server | `ssh -i ~/.ssh/likho_deploy deploy@$(terraform -chdir=deploy/terraform output -raw server_ip)` |
| API logs | on the server: `cd /srv/likho/src/deploy && docker compose logs -f api` |
| Who is banned | on the server: `sudo fail2ban-client status` |

## Security

**Network**
- Two firewalls: Vultr's, before traffic reaches the machine, and `ufw` on it. Only 80 and 443
  are open to everyone.
- SSH (port 22) is open only to the IP of the computer that ran `terraform apply` (or
  `ssh_allowed_cidrs`).
- Postgres and Redis have no port at all; they are on Likho's private Docker network. The API
  listens on `127.0.0.1` only, behind nginx.
- Bots scanning the server's IP get no answer: plain HTTP closes the connection, and HTTPS refuses
  the handshake without a certificate.

**SSH**
- Key only: no passwords, no root login, and only the `deploy` user.
- Modern ciphers only, at most 3 tries per connection.
- fail2ban bans IPs that keep guessing.

**HTTPS**
- Let's Encrypt certificate with TLS 1.2 and 1.3 only, renewed automatically.
- HSTS for two years.
- CAA records limit who may issue certificates for the domain (on Vercel: Let's Encrypt, Google and Sectigo; with `dns_on_vultr`, only Let's Encrypt).

**Abuse and scraping**
- nginx limits each IP:
  - sign-in: 20 a minute
  - API: 10 a second
  - media: 40 a second
  - connections: 40 at a time
- The API limits again, per IP and per parent account.
- The API trusts the client IP only from nginx, so a fake `X-Forwarded-For` cannot get around the
  limits.
- fail2ban bans IPs that keep hitting the limits or probing for files like `.env` or `wp-admin`.
  Repeat offenders are banned for a week.
- Families' data (accounts, children, progress) is only reachable with that family's own sign-in
  token.

**Admin panel**
- At `admin.likho.io` only (`api.likho.io/admin` answers 404); `admin_on_internet = false` in
  Terraform takes it off the internet again (then only the SSH tunnel reaches it).
- Signing in takes the password and then a 6-digit code from an authenticator app (Google
  Authenticator, Microsoft Authenticator, 1Password), set up with a QR code at the first sign-in.
  A session without it does not count.
- 5 wrong passwords or codes lock that account for 15 minutes, whatever the IP; nginx also allows
  only a few sign-in tries per IP. Failed sign-ins are in the panel's audit log.
- The page has a strict content security policy, is never indexed, and its cookie is HttpOnly,
  Secure, SameSite=Strict and only for that name.
- Its DNS: `admin` A and AAAA records to the server (`terraform output dns_records`). Until they
  point here, deploys leave the admin name out and the tunnel still works.

**Secrets**
- Made on the server by `server-setup.sh` the first time. They never travel and are never in git:
  - Postgres password
  - Redis password
  - JWT key
  - admin password
- `deploy/.env` on the server is readable by `deploy` only.
- The Vultr API key stays in `~/.config/likho/vultr.env`.
- The Terraform state (`terraform/terraform.tfstate`) holds the server's root password (for
  Vultr's web console only). Keep it on your computer and in your own backup, never in git.

**Containers**
- No container can gain privileges.
- The API: read-only, distroless, runs as non-root, all Linux capabilities dropped.
- Redis: password, no disk, dangerous commands (CONFIG, DEBUG) disabled.
- Memory and CPU caps on every service.

**Updates**
- Ubuntu security updates install every night.
- The machine reboots at 03:00 Pakistan time when an update needs it. Containers come back by
  themselves.

**Backups**
- The database is dumped every night at 01:30 Pakistan time and kept 14 days in
  `/srv/likho/backups`.
- Vultr copies the whole disk every night at 02:00, so each dump also lives off the machine.

**Safety**
- `terraform destroy` and any change that would replace the server are blocked
  (`prevent_destroy`), because the database is on its disk.

## If something goes wrong

- **SSH times out:** your IP changed. Run `terraform apply` again (see Every day).
- **SSH key lost:** use Vultr's web console (server → View Console) with
  `terraform -chdir=deploy/terraform output -raw root_password`. Then add a new key to
  `/home/deploy/.ssh/authorized_keys`.
- **Restore the database:**

  ```bash
  gunzip -c /srv/likho/backups/<file>.sql.gz | docker compose exec -T postgres psql -U likho -d likho
  ```

  Run it in `/srv/likho/src/deploy`, after stopping the API (`docker compose stop api`). The dump
  replaces the tables it contains. For a whole-disk restore, use Vultr →
  server → Backups.
