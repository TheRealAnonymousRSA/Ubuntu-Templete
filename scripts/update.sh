#!/usr/bin/env bash
#
# update.sh  (installed as the `update` command)
#
# Updates the package index and upgrades installed packages. Uses sudo
# explicitly so it works the same whether invoked by root or by the
# sudo-capable login user.

set -euo pipefail

echo "Updating package lists..."
sudo apt-get update

echo "Upgrading installed packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "Done."
