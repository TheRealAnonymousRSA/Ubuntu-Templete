#!/usr/bin/env bash
#
# banner.sh
#
# Prints the project banner followed by a live system-info snapshot.
# Sourced by /etc/profile.d/00-vps-shell.sh on every new interactive login
# (i.e. every time a browser tab opens a new ttyd terminal), and also run
# once by entrypoint.sh at container startup for `docker logs` visibility.

set -uo pipefail

if [ -r /etc/vps-banner.txt ]; then
    cat /etc/vps-banner.txt
else
    echo "TheRealAnonymousRSA-VPS"
fi

echo
/usr/local/lib/vps/sysinfo.sh
echo
