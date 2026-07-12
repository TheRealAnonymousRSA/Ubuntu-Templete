#!/usr/bin/env bash
#
# entrypoint.sh
#
# Runs as tini's direct child (effectively PID 2, with tini as PID 1).
# Performs one-time, idempotent root-level setup:
#   - resolves PORT / USERNAME / PASSWORD / TZ from the environment
#   - configures the timezone
#   - creates or updates the Linux user account and its sudo rights
#   - records a session start time for uptime reporting
#   - prints the banner and (if generated) the one-time password notice
#
# It then hands off to start.sh via `exec`, so no wrapper shell is left
# sitting between tini and ttyd.

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Record session start time (used by sysinfo.sh for container uptime)
# ---------------------------------------------------------------------------
date +%s > /var/run/vps-start-time

# ---------------------------------------------------------------------------
# 1. Resolve configuration from environment, with sane defaults
# ---------------------------------------------------------------------------
: "${PORT:=7681}"
: "${USERNAME:=admin}"
: "${TZ:=UTC}"
: "${SUDO_NOPASSWD:=true}"
: "${ENABLE_SSL:=false}"

export PORT USERNAME TZ SUDO_NOPASSWD ENABLE_SSL

# ---------------------------------------------------------------------------
# 2. Timezone
# ---------------------------------------------------------------------------
if [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
else
    echo "[entrypoint] Warning: TZ='${TZ}' not recognized, falling back to UTC" >&2
    TZ=UTC
    export TZ
    ln -snf /usr/share/zoneinfo/UTC /etc/localtime
    echo "UTC" > /etc/timezone
fi

# ---------------------------------------------------------------------------
# 3. Resolve the login password
# ---------------------------------------------------------------------------
GENERATED_PASSWORD=false
if [ -z "${PASSWORD:-}" ]; then
    PASSWORD="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)"
    GENERATED_PASSWORD=true
fi
export PASSWORD

# ---------------------------------------------------------------------------
# 4. Create/update the Linux user account (idempotent)
# ---------------------------------------------------------------------------
/usr/local/lib/vps/user-setup.sh "${USERNAME}" "${PASSWORD}" "${SUDO_NOPASSWD}"

# ---------------------------------------------------------------------------
# 5. Banner + one-time credentials notice (visible in `docker logs`)
# ---------------------------------------------------------------------------
/usr/local/lib/vps/banner.sh

if [ "${GENERATED_PASSWORD}" = true ]; then
    cat <<EOF

==================================================================
 No PASSWORD was set - a random password has been generated:

   Username : ${USERNAME}
   Password : ${PASSWORD}

 This will not be shown again. Set the PASSWORD environment
 variable on your next run if you want a password you control.
==================================================================

EOF
fi

echo "[entrypoint] Handing off to start.sh (PORT=${PORT}, USERNAME=${USERNAME}, ENABLE_SSL=${ENABLE_SSL})"

exec /usr/local/bin/start.sh
