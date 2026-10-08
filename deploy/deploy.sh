#!/usr/bin/env bash
# Deploys Likho to one server over SSH, from this computer:
#
#   deploy/deploy.sh user@server            # code, admin panel, media, restart
#   deploy/deploy.sh user@server media      # only new pictures and recordings
#
# On the server: Docker with the compose plugin, rsync, and deploy/.env
# filled in once (see deploy/.env.example). Everything goes under
# LIKHO_DIR (default /srv/likho):
#   src/     the backend and deploy/ (the image is built there)
#   media/   pictures and recordings (repo media/, not in git)
#   admin/   the admin panel's build
# Copies are incremental (rsync): only changed files travel.
set -euo pipefail

server="${1:?usage: deploy/deploy.sh user@server [media]}"
what="${2:-all}"
dir="${LIKHO_DIR:-/srv/likho}"
root="$(cd "$(dirname "$0")/.." && pwd)"
rs=(rsync -az --delete --human-readable)

echo "▸ checking that every picture and recording the content uses is in media/"
(cd "$root/backend" && go run ./cmd/content media-check -media ../media)

ssh "$server" "mkdir -p $dir/src $dir/media $dir/admin"

echo "▸ media → $server:$dir/media"
"${rs[@]}" --checksum "$root/media/" "$server:$dir/media/"

if [[ "$what" != "media" ]]; then
  echo "▸ admin panel"
  (cd "$root/admin" && npm run -s build)
  "${rs[@]}" "$root/admin/dist/" "$server:$dir/admin/"

  echo "▸ code"
  "${rs[@]}" --exclude bin/ --exclude geoip/ --exclude .env "$root/backend" "$server:$dir/src/"
  "${rs[@]}" --exclude .env "$root/deploy" "$server:$dir/src/"

  echo "▸ build and start"
  ssh "$server" "cd $dir/src/deploy && test -f .env || { echo 'fill in $dir/src/deploy/.env first (see .env.example)'; exit 1; }; docker compose up -d --build --remove-orphans && docker image prune -f >/dev/null"
fi

# the API indexes the media folder at start: restart it to pick up new files
echo "▸ restart the API"
ssh "$server" "cd $dir/src/deploy && docker compose restart api >/dev/null && for i in \$(seq 1 30); do docker compose exec -T api /likho-api health && exit 0; sleep 1; done; echo 'API not ready: docker compose logs api'; exit 1"
echo "✓ deployed: the API is ready"
