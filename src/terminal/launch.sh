#!/usr/bin/env bash
#
# src/terminal/launch.sh
#
# Builds the ttyd command line and execs it - this becomes the final
# process in the chain (tini -> launch.sh -> ttyd), so ttyd inherits PID
# from tini's perspective with nothing left running underneath it.
#
# Terminal UX features are implemented entirely through ttyd's own
# documented, supported mechanisms (client-options) rather than a custom
# frontend:
#   - Multiple themes  -> `-t theme=<json>`, chosen via TERMINAL_THEME
#   - Custom title     -> `-t titleFixed=<name>`
#   - Session reconnect -> a persistent tmux session ("main"); ttyd's own
#     client already retries the websocket on drop by default (we do not
#     set disableReconnect=true), so a dropped connection reattaches to
#     the same tmux session instead of losing state.
#   - Clipboard support -> already built into ttyd's bundled xterm.js
#     frontend (native OS copy/paste); nothing to add here.
#   - Fullscreen mode   -> standard browser fullscreen (F11 / browser UI);
#     the terminal already fills its container responsively.

set -euo pipefail

# shellcheck source=src/core/logging.sh
source /opt/tra/core/logging.sh

: "${PORT:=8080}"
: "${USERNAME:=admin}"
: "${PASSWORD:?PASSWORD must be set before launch.sh runs (entrypoint.sh sets this)}"
: "${ENABLE_SSL:=false}"
: "${TERMINAL_THEME:=dark}"

theme_json="$(/opt/tra/config/themes.sh --json "${TERMINAL_THEME}")"

ttyd_args=(
    --port "${PORT}"
    --interface 0.0.0.0
    --credential "${USERNAME}:${PASSWORD}"
    --writable
    --client-option "titleFixed=TheRealAnonymousRSA VPS"
    --client-option "theme=${theme_json}"
)

if [ "${ENABLE_SSL}" = "true" ]; then
    : "${SSL_CERT_PATH:?SSL_CERT_PATH must be set when ENABLE_SSL=true}"
    : "${SSL_KEY_PATH:?SSL_KEY_PATH must be set when ENABLE_SSL=true}"
    ttyd_args+=(--ssl --ssl-cert "${SSL_CERT_PATH}" --ssl-key "${SSL_KEY_PATH}")
    log_info "TLS enabled (cert: ${SSL_CERT_PATH})"
else
    log_info "TLS disabled - put a reverse proxy (Caddy/nginx/Traefik) in front of this for anything beyond localhost or a trusted private network"
fi

log_info "Starting ttyd on 0.0.0.0:${PORT} as user '${USERNAME}' (theme: ${TERMINAL_THEME})"

# `su -` is run by ttyd, which is still root at this point, so no second
# password prompt is shown - ttyd's own --credential Basic Auth check is
# the only login gate the connecting browser sees. `tmux new-session -A`
# creates the "main" session on first connect and reattaches to it on
# every subsequent one, which is what makes reconnects land back in the
# same shell instead of a fresh one.
exec ttyd "${ttyd_args[@]}" su - "${USERNAME}" -c "tmux new-session -A -s main"
