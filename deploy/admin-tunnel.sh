#!/usr/bin/env bash
# Opens the admin panel through SSH: it is never on the internet (nginx
# answers 404 for /admin). Only computers with the deploy key, from an IP
# the firewall allows, can reach it.
#
#   deploy/admin-tunnel.sh      then open http://localhost:18080/admin/
#
# Ctrl+C closes the tunnel.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$root/deploy/server.env"
port="${1:-18080}"
echo "admin panel: http://localhost:$port/admin/  (Ctrl+C to close)"
exec ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes -N -L "$port:127.0.0.1:8080" "$SSH_USER@$SERVER_IP"
