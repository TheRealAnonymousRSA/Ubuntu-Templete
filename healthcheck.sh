#!/usr/bin/env bash
#
# healthcheck.sh
#
# Confirms ttyd is alive and serving HTTP(S) on $PORT. Used both as the
# Docker HEALTHCHECK command and as the `tra-status` command's health
# line (same script, symlinked as tra-status calls it directly).
#
# ttyd requires Basic Auth, so an unauthenticated request correctly gets a
# 401 rather than a 200 - both are treated as "healthy" here, since either
# one proves ttyd is up and responding. A connection failure (curl exit
# nonzero, code "000") means it is not.
#
# Note: the tmux session ("main") is created lazily on the *first* client
# connection, not at container startup - so its absence immediately after
# boot is completely normal and is deliberately NOT treated as unhealthy
# here. `tra-status` reports it separately as informational context.

set -uo pipefail

# PORT/ENABLE_SSL are set directly when Docker's HEALTHCHECK runs this (it
# inherits the container's environment). When a logged-in user runs this
# manually (via `tra-health` / `tra-status`), `su -` has reset the
# environment, so fall back to the TRA_-prefixed copies entrypoint.sh
# persisted into /etc/environment specifically so this still works there.
: "${PORT:=${TRA_PORT:-8080}}"
: "${ENABLE_SSL:=${TRA_ENABLE_SSL:-false}}"

if [ "${ENABLE_SSL}" = "true" ]; then
    scheme="https"
    curl_opts=(-k)
else
    scheme="http"
    curl_opts=()
fi

code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${curl_opts[@]}" "${scheme}://127.0.0.1:${PORT}/" 2>/dev/null || echo "000")"

if [[ "${code}" =~ ^(200|401)$ ]]; then
    exit 0
fi

echo "Healthcheck failed: got HTTP ${code} from ${scheme}://127.0.0.1:${PORT}/" >&2
exit 1
