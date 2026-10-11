#!/usr/bin/env bash
# Runs ON the server, as root, from deploy.sh (never by hand). Idempotent:
#   1. deploy/.env with fresh random secrets, the first time only (the
#      secrets are made on the server and never travel)
#   2. nginx: hardening, the catch-all for scanners, Likho's sites
#   3. the HTTPS certificate (Let's Encrypt), renewed by certbot by itself
# Needs API_DOMAIN and LETSENCRYPT_EMAIL; SITE_DOMAIN only when the server
# serves the website too. GOOGLE_CLIENT_IDS and ADMIN_EMAIL go into .env.
set -euo pipefail

: "${API_DOMAIN:?}" "${LETSENCRYPT_EMAIL:?}"
SITE_DOMAIN="${SITE_DOMAIN:-}"
here="$(cd "$(dirname "$0")" && pwd)"
env_file="$here/.env"
names=("$API_DOMAIN")
[[ -n "$SITE_DOMAIN" ]] && names+=("$SITE_DOMAIN" "www.$SITE_DOMAIN")

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

# ------------------------------------------------------------------ Google Play Billing
# The key in the notifications' push URL, made here once and kept in .env.
if ! grep -q '^PLAY_NOTIFY_KEY=' "$env_file"; then
  echo "PLAY_NOTIFY_KEY=$(secret 32 32)" >> "$env_file"
  echo "▸ new Google Play notifications key in $env_file"
fi
notify_key="$(grep '^PLAY_NOTIFY_KEY=' "$env_file" | cut -d= -f2-)"
echo "  play notifications: https://$API_DOMAIN/v1/play/notifications?key=$notify_key  (secret: the Pub/Sub push endpoint)"

# The service account key deploy.sh sent (deploy/incoming): only the API's
# user (distroless nonroot, uid 65532) can read it.
secrets_dir="${LIKHO_DIR:-/srv/likho}/secrets"
install -d -m 755 -o root -g root "$secrets_dir"
if [[ -f "$here/incoming/play-service-account.json" ]]; then
  install -m 400 -o 65532 -g 65532 "$here/incoming/play-service-account.json" "$secrets_dir/play-service-account.json"
  rm -f "$here/incoming/play-service-account.json"
fi
if [[ -f "$secrets_dir/play-service-account.json" ]]; then
  grep -q '^PLAY_SERVICE_ACCOUNT_FILE=' "$env_file" ||
    echo "PLAY_SERVICE_ACCOUNT_FILE=/run/secrets/likho/play-service-account.json" >> "$env_file"
  echo "▸ Google Play Billing: service account key installed"
else
  echo "▸ Google Play Billing: no service account key yet (~/.config/likho/play-service-account.json on your computer)"
fi

# ------------------------------------------------------------------ nginx
fill() { sed -e "s/__API_DOMAIN__/$API_DOMAIN/g" -e "s/__SITE_DOMAIN__/$SITE_DOMAIN/g" -e "s/__NAMES__/${names[*]}/g" "$1"; }

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
      echo "  Add its A record (terraform output dns_records) where the domain's DNS is, wait for DNS, then deploy again."
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
if [[ -n "$SITE_DOMAIN" ]]; then
  fill "$here/nginx/likho-site.conf" > /etc/nginx/sites-enabled/likho-site
else
  rm -f /etc/nginx/sites-enabled/likho-site
fi
nginx -t -q
systemctl reload nginx
echo "▸ nginx and HTTPS ready: ${names[*]}"
