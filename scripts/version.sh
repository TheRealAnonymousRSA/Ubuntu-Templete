#!/usr/bin/env bash
#
# version.sh  (installed as the `version` command)
#
# Prints this project's version plus the underlying system/ttyd versions.

set -uo pipefail

project_version="unknown"
if [ -r /etc/vps-version ]; then
    project_version="$(cat /etc/vps-version)"
fi

echo "TheRealAnonymousRSA-VPS v${project_version}"
echo
/usr/local/lib/vps/sysinfo.sh
