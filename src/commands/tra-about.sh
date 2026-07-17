#!/usr/bin/env bash
#
# tra-about
#
# Prints project identity and a short description.

set -uo pipefail

version="unknown"
[ -r /etc/tra-version ] && version="$(cat /etc/tra-version)"

cat <<EOF
TheRealAnonymousRSA VPS  v${version}

A self-hosted, browser-based Kali Linux Rolling terminal, built on ttyd,
tmux, and Docker. Run 'tra-help' to see the available commands.

This runs inside a Docker container - the branded banner, prompt, and
hostname display are just cosmetic; 'hostname' and 'tra-version' will
show you the underlying system directly if you want it.

License: MIT
EOF
