#!/usr/bin/env bash
#
# healthcheck.sh
#
# Confirms ttyd is alive and serving HTTP(S) on $PORT. Used both as the
# Docker HEALTHCHECK command and as the `health` helper command inside a
# logged-in terminal session (they are the same script, symlinked).
#
# ttyd requires Basic Auth, so an unauthenticated request correctly gets a
# 401 rather than a 200 -- both are treated as "healthy" here, since either
# one proves ttyd is up and responding. A connection failure (curl exit
# nonzero, code "000") means it is not.

set -uo pipefail

: "${PORT:=7681}"
: "${ENABLE_SSL:=false}"

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
