#!/usr/bin/env bash
# Deploys Likho to its server, from this computer (see README.md):
#
#   deploy/deploy.sh            # everything: code, website, admin panel, media
#   deploy/deploy.sh media      # only new pictures and recordings
#
# Where the server is comes from deploy/server.env (written by terraform).
# Everything goes under /srv/likho on the server:
#   src/     the backend and deploy/ (the API image is built there)
#   media/   pictures and recordings (repo media/, not in git)
#   admin/   the admin panel's build
#   site/    the website (landing/, a static export)
#   geoip/   the country database for the admin panel
# Copies are incremental (rsync): only changed files travel. One SSH
# connection is reused for every step.
set -euo pipefail

what="${1:-all}"
root="$(cd "$(dirname "$0")/.." && pwd)"
conf="$root/deploy/server.env"
[[ -f "$conf" ]] || { echo "no deploy/server.env: run terraform apply in deploy/terraform first (README.md)"; exit 1; }
# shellcheck source=/dev/null
source "$conf"
dir=/srv/likho
target="$SSH_USER@$SERVER_IP"

ctl="$(mktemp -d /tmp/likho.XXXXXX)" # short: a socket path must stay under 104 bytes (macOS)
ssh_opts=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new
  -o ControlMaster=auto -o "ControlPath=$ctl/%C" -o ControlPersist=120)
ssh "${ssh_opts[@]}" -fN "$target"
trap 'ssh "${ssh_opts[@]}" -O exit "$target" 2>/dev/null; rm -rf "$ctl"' EXIT
on() { ssh "${ssh_opts[@]}" "$target" "$@"; }
rs=(rsync -az --delete --human-readable -e "ssh ${ssh_opts[*]}")

echo "▸ waiting for the server's first-boot setup"
for _ in $(seq 1 60); do on test -f /var/lib/likho-ready && break; sleep 10; done
on test -f /var/lib/likho-ready || { echo "first-boot setup not finished: ssh in and check 'cloud-init status --long'"; exit 1; }

echo "▸ checking that every picture and recording the content uses is in media/"
(cd "$root/backend" && go run ./cmd/content media-check -media ../media)

on "mkdir -p $dir/src $dir/media $dir/admin $dir/site $dir/geoip"

echo "▸ media"
"${rs[@]}" --checksum "$root/media/" "$target:$dir/media/"

if [[ "$what" != "media" ]]; then
  echo "▸ admin panel"
  (cd "$root/admin" && npm run -s build)
  "${rs[@]}" "$root/admin/dist/" "$target:$dir/admin/"

  if [[ -n "${SITE_DOMAIN:-}" ]]; then
    echo "▸ website"
    (cd "$root/landing" && NEXT_PUBLIC_SITE_URL="https://$SITE_DOMAIN" npm run -s build)
    "${rs[@]}" "$root/landing/out/" "$target:$dir/site/"
  fi

  if [[ -f "$root/backend/geoip/country.mmdb" ]]; then
    "${rs[@]}" "$root/backend/geoip/country.mmdb" "$target:$dir/geoip/"
  fi

  echo "▸ code"
  "${rs[@]}" --exclude bin/ --exclude geoip/ --exclude .env "$root/backend" "$target:$dir/src/"
  "${rs[@]}" --exclude .env --exclude server.env --exclude terraform/ "$root/deploy" "$target:$dir/src/"

  echo "▸ secrets, nginx and HTTPS"
  on "sudo API_DOMAIN='$API_DOMAIN' SITE_DOMAIN='${SITE_DOMAIN:-}' LETSENCRYPT_EMAIL='$LETSENCRYPT_EMAIL' GOOGLE_CLIENT_IDS='$GOOGLE_CLIENT_IDS' ADMIN_EMAIL='$ADMIN_EMAIL' bash $dir/src/deploy/server-setup.sh"

  echo "▸ build and start"
  on "cd $dir/src/deploy && docker compose up -d --build --remove-orphans && docker image prune -f >/dev/null"
fi

# the API indexes the media folder at start: restart it to pick up new files
echo "▸ restart the API"
on "cd $dir/src/deploy && docker compose restart api >/dev/null && for i in \$(seq 1 30); do docker compose exec -T api /likho-api health && exit 0; sleep 1; done; echo 'API not ready: docker compose logs api'; exit 1"

curl -fsS --max-time 10 "https://$API_DOMAIN/healthz" >/dev/null && echo "✓ deployed: https://$API_DOMAIN${SITE_DOMAIN:+ and https://$SITE_DOMAIN}"
