#!/usr/bin/env bash
# Runs ON the server, as root, from deploy.sh (never by hand). Idempotent:
#   1. deploy/.env with fresh random secrets, the first time only (the
#      secrets are made on the server and never travel)
#   2. nginx: hardening, the catch-all for scanners, Likho's sites
#   3. the HTTPS certificate (Let's Encrypt), renewed by certbot by itself
# Needs API_DOMAIN, SITE_DOMAIN and LETSENCRYPT_EMAIL; GOOGLE_CLIENT_IDS and
# ADMIN_EMAIL go into .env.
set -euo pipefail

: "${API_DOMAIN:?}" "${SITE_DOMAIN:?}" "${LETSENCRYPT_EMAIL:?}"
here="$(cd "$(dirname "$0")" && pwd)"
env_file="$here/.env"
names=("$API_DOMAIN" "$SITE_DOMAIN" "www.$SITE_DOMAIN")

secret() { openssl rand -base64 "$1" | tr -d '\n/+=' | cut -c "1-$2"; }

# ------------------------------------------------------------------ secrets
if [[ ! -f "$env_file" ]]; then
  admin_password="$(secret 24 24)"
  umask 077
  cat > "$env_file" <<EOF
# Made on the server by server-setup.sh. Secrets: never copy them anywhere.
LIKHO_DIR=/srv/likho
LIKHO_PORT=8080
POSTGRES_PASSWORD=$(secret 32 32)
REDIS_PASSWORD=$(secret 32 32)
JWT_SECRET=$(secret 64 64)
GOOGLE_CLIENT_IDS=${GOOGLE_CLIENT_IDS:-}
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=1440h
ADMIN_BOOTSTRAP_EMAIL=${ADMIN_EMAIL:-}
ADMIN_BOOTSTRAP_PASSWORD=$admin_password
EOF
  chown deploy:deploy "$env_file"
  chmod 600 "$env_file"
  echo "▸ new secrets in $env_file"
  echo "  admin panel: ${ADMIN_EMAIL:-?} / $admin_password  (shown once: save it, then change it in the panel)"
elif [[ -n "${GOOGLE_CLIENT_IDS:-}" ]]; then
  # client IDs may change (they are not secret): keep them in step
  sed -i "s|^GOOGLE_CLIENT_IDS=.*|GOOGLE_CLIENT_IDS=$GOOGLE_CLIENT_IDS|" "$env_file"
fi

# ------------------------------------------------------------------ nginx
fill() { sed -e "s/__API_DOMAIN__/$API_DOMAIN/g" -e "s/__SITE_DOMAIN__/$SITE_DOMAIN/g" "$1"; }

install -m 644 "$here/nginx/hardening.conf" /etc/nginx/conf.d/likho-hardening.conf
install -m 644 "$here/nginx/headers.conf" /etc/nginx/snippets/likho-headers.conf
install -m 644 "$here/nginx/proxy.conf" /etc/nginx/snippets/likho-proxy.conf
install -m 644 "$here/nginx/tls.conf" /etc/nginx/snippets/likho-tls.conf
install -m 644 "$here/nginx/default.conf" /etc/nginx/sites-enabled/00-default
fill "$here/nginx/likho-http.conf" > /etc/nginx/sites-enabled/likho-http
rm -f /etc/nginx/sites-enabled/default
nginx -t -q
systemctl reload nginx

# ------------------------------------------------------------------ HTTPS
if [[ ! -d /etc/letsencrypt/live/likho ]]; then
  # Let's Encrypt can only check names that already point here
  ip="$(curl -fsS4 --max-time 5 https://ipv4.icanhazip.com || true)"
  for n in "${names[@]}"; do
    got="$({ getent ahostsv4 "$n" || true; } | awk 'NR==1{print $1}')"
    if [[ "$got" != "$ip" ]]; then
      echo "✗ $n points to '${got:-nothing}', not to this server ($ip)."
      echo "  Set the domain's nameservers to ns1.vultr.com and ns2.vultr.com, wait for DNS, then deploy again."
      exit 1
    fi
  done
fi
args=()
for n in "${names[@]}"; do args+=(-d "$n"); done
certbot certonly --webroot -w /var/www/acme --cert-name likho "${args[@]}" \
  --email "$LETSENCRYPT_EMAIL" --agree-tos --no-eff-email --non-interactive \
  --keep-until-expiring --expand --key-type ecdsa \
  --deploy-hook "systemctl reload nginx" >/dev/null
fill "$here/nginx/likho.conf" > /etc/nginx/sites-enabled/likho
nginx -t -q
systemctl reload nginx
echo "▸ nginx and HTTPS ready: ${names[*]}"
