#!/usr/bin/env bash
# Opens the admin panel through SSH: the way in when admin.<domain> is off
# (admin_on_internet = false) or its DNS is not there yet. Only computers
# with the deploy key, from an IP the firewall allows, can reach it; the
# panel still asks for the password and the authenticator code.
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
