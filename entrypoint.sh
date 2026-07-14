#!/usr/bin/env bash
#
# entrypoint.sh
#
# Runs as tini's direct child (tini is PID 1; see Dockerfile). Performs
# one-time, idempotent root-level setup, then hands off to start.sh via
# `exec` so no wrapper shell is left sitting between tini and ttyd.
#
# bootstrap.sh is *sourced*, not executed as a subprocess - a subprocess's
# environment-variable fixes (e.g. falling back to a valid PORT) would be
# invisible to this shell once it exited. Sourcing keeps everything in one
# process so the corrected values actually take effect.

set -euo pipefail

date +%s > /var/run/tra-start-time

# shellcheck source=src/core/logging.sh
source /opt/tra/core/logging.sh
# shellcheck source=src/core/bootstrap.sh
source /opt/tra/core/bootstrap.sh

# ---------------------------------------------------------------------------
# Resolve the login password (not part of bootstrap.sh's validation, since
# it needs to be generated fresh - not merely checked - when absent)
# ---------------------------------------------------------------------------
GENERATED_PASSWORD=false
if [ -z "${PASSWORD:-}" ]; then
    PASSWORD="TRA"
    GENERATED_PASSWORD=true
fi
export PASSWORD

# ---------------------------------------------------------------------------
# Timezone
# ---------------------------------------------------------------------------
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
echo "${TZ}" > /etc/timezone

# ---------------------------------------------------------------------------
# Create/update the Linux user account (idempotent)
# ---------------------------------------------------------------------------
/opt/tra/core/user-setup.sh "${USERNAME}" "${PASSWORD}" "${SUDO_NOPASSWD}"

# ---------------------------------------------------------------------------
# Persist the values healthcheck.sh needs into /etc/environment
# ---------------------------------------------------------------------------
# `su -` (used to land in the login user's shell - see launch.sh) resets the
# environment as real logins do, so PORT/ENABLE_SSL as set on the container
# are NOT visible inside a logged-in terminal session. Without this, running
# `tra-health` (or `tra-status`, which calls it) from inside the terminal
# would silently check the wrong port whenever PORT is not the default 7681.
# /etc/environment is read by PAM for every login shell, `su -` included, so
# writing TRA_-prefixed copies here makes them survive that reset.
# Idempotent: strip any previous TRA_PORT/TRA_ENABLE_SSL lines before adding
# the current ones, so restarting the same container doesn't grow this file.
sed -i '/^TRA_PORT=/d;/^TRA_ENABLE_SSL=/d' /etc/environment
{
    echo "TRA_PORT=${PORT}"
    echo "TRA_ENABLE_SSL=${ENABLE_SSL}"
} >> /etc/environment

# ---------------------------------------------------------------------------
# Banner + one-time credentials notice (visible in `docker logs`)
# ---------------------------------------------------------------------------
/opt/tra/branding/banner.sh

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

log_info "Handing off to start.sh"

exec /usr/local/bin/start.sh
