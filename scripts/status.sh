#!/usr/bin/env bash
#
# status.sh  (installed as the `status` command)
#
# A quick operational snapshot: system info plus who is logged in and
# whether the ttyd process itself is actually running.

set -uo pipefail

echo "=== TheRealAnonymousRSA-VPS status ==="
/usr/local/lib/vps/sysinfo.sh
echo
echo "Logged in as  : $(whoami)"

if pgrep -x ttyd >/dev/null 2>&1; then
    pid="$(pgrep -x ttyd | head -n1)"
    echo "ttyd process  : running (pid ${pid})"
else
    echo "ttyd process  : not detected"
fi

if /healthcheck.sh >/dev/null 2>&1; then
    echo "Health        : OK"
else
    echo "Health        : FAILING (run 'health' for details)"
fi
