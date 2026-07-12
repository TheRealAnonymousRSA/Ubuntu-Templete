#!/usr/bin/env bash
#
# update.sh  (installed as the `update` command)
#
# Updates the package index and upgrades installed packages. Uses sudo
# explicitly so it works the same whether invoked by root or by the
# sudo-capable login user.

set -Eeuo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

echo "Updating package lists..."
sudo apt-get update

echo "Upgrading installed packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "Done."
