#!/usr/bin/env bash
#
# start.sh
#
# Final launch step. Assumes entrypoint.sh has already run and exported
# PORT, USERNAME, PASSWORD, TZ, SUDO_NOPASSWD, ENABLE_SSL. Builds the ttyd
# argument list and execs it directly, so ttyd becomes tini's child process
# with no wrapper shell left running underneath it.

set -euo pipefail

: "${PORT:=7681}"
: "${USERNAME:=admin}"
: "${PASSWORD:?PASSWORD must be set before start.sh runs (entrypoint.sh sets this)}"
: "${ENABLE_SSL:=false}"

ttyd_args=(
    --port "${PORT}"
    --interface 0.0.0.0
    --credential "${USERNAME}:${PASSWORD}"
    --writable
)

if [ "${ENABLE_SSL}" = "true" ]; then
    : "${SSL_CERT_PATH:?SSL_CERT_PATH must be set when ENABLE_SSL=true}"
    : "${SSL_KEY_PATH:?SSL_KEY_PATH must be set when ENABLE_SSL=true}"
    ttyd_args+=(--ssl --ssl-cert "${SSL_CERT_PATH}" --ssl-key "${SSL_KEY_PATH}")
    echo "[start] TLS enabled (cert: ${SSL_CERT_PATH})"
else
    echo "[start] TLS disabled - put a reverse proxy (Caddy/nginx/Traefik) in front of this for anything beyond localhost or a trusted private network"
fi

echo "[start] Starting ttyd on 0.0.0.0:${PORT} as user '${USERNAME}'"

# `su - "$USERNAME"` is run by ttyd, which is still root at this point, so
# no second password prompt is shown -- ttyd's own --credential basic-auth
# check is the only login gate the connecting browser sees.
exec ttyd "${ttyd_args[@]}" su - "${USERNAME}"
