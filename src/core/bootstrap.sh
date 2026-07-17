#!/usr/bin/env bash
#
# src/core/bootstrap.sh
#
# Runs once, early in entrypoint.sh, as root. Two jobs:
#   1. Verify every binary this image depends on is actually present and
#      executable (fail fast with a clear error instead of a confusing
#      failure three steps later).
#   2. Validate the environment variables that configure this container,
#      applying safe fallbacks and warning loudly when a value is invalid,
#      rather than silently misbehaving at runtime.

set -euo pipefail

# shellcheck source=src/core/logging.sh
source /opt/tra/core/logging.sh

# ---------------------------------------------------------------------------
# 1. Dependency verification
# ---------------------------------------------------------------------------
REQUIRED_BINARIES=(
    ttyd tmux sudo curl wget git nano vim htop jq zip unzip
    ssh ping traceroute ip netstat useradd usermod chpasswd visudo
)

missing=()
for bin in "${REQUIRED_BINARIES[@]}"; do
    if ! command -v "${bin}" >/dev/null 2>&1; then
        missing+=("${bin}")
    fi
done

if [ "${#missing[@]}" -gt 0 ]; then
    log_error "Missing required binaries: ${missing[*]}"
    log_error "The image is not built correctly - this should never happen in the official image."
    exit 1
fi
log_info "Dependency check passed (${#REQUIRED_BINARIES[@]} binaries verified)"

# ---------------------------------------------------------------------------
# Helper: strip whitespace/newlines some platforms inject into env var
# values (e.g. a trailing newline from how they're piped into the
# container), so a value like $'8080\n' validates the same as "8080"
# instead of being spuriously rejected.
# ---------------------------------------------------------------------------
_trim() {
    tr -d '[:space:]' <<< "$1"
}

# ---------------------------------------------------------------------------
# 2. Environment validation
# ---------------------------------------------------------------------------

# PORT: must be a number in the valid TCP port range
: "${PORT:=8080}"
PORT="$(_trim "${PORT}")"
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
    log_warn "PORT='${PORT}' is not a valid port number, falling back to 8080"
    PORT="8080"
fi
export PORT

# USERNAME: safe Linux username pattern
: "${USERNAME:=admin}"
USERNAME="$(_trim "${USERNAME}")"
if ! [[ "${USERNAME}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log_warn "USERNAME='${USERNAME}' is not a valid Linux username, falling back to 'admin'"
    USERNAME="admin"
fi
export USERNAME

# TZ: must exist under /usr/share/zoneinfo
: "${TZ:=UTC}"
TZ="$(_trim "${TZ}")"
if [ ! -f "/usr/share/zoneinfo/${TZ}" ]; then
    log_warn "TZ='${TZ}' is not a recognized timezone, falling back to UTC"
    TZ="UTC"
fi
export TZ

# SUDO_NOPASSWD: must be literally "true" or "false"
: "${SUDO_NOPASSWD:=true}"
SUDO_NOPASSWD="$(_trim "${SUDO_NOPASSWD}")"
if [ "${SUDO_NOPASSWD}" != "true" ] && [ "${SUDO_NOPASSWD}" != "false" ]; then
    log_warn "SUDO_NOPASSWD='${SUDO_NOPASSWD}' is not true/false, falling back to true"
    SUDO_NOPASSWD="true"
fi
export SUDO_NOPASSWD

# ENABLE_SSL: must be literally "true" or "false"
: "${ENABLE_SSL:=false}"
ENABLE_SSL="$(_trim "${ENABLE_SSL}")"
if [ "${ENABLE_SSL}" != "true" ] && [ "${ENABLE_SSL}" != "false" ]; then
    log_warn "ENABLE_SSL='${ENABLE_SSL}' is not true/false, falling back to false"
    ENABLE_SSL="false"
fi
export ENABLE_SSL

# TERMINAL_THEME: must be one of the presets shipped in config/themes.sh
: "${TERMINAL_THEME:=dark}"
TERMINAL_THEME="$(_trim "${TERMINAL_THEME}")"
if ! /opt/tra/config/themes.sh --has "${TERMINAL_THEME}"; then
    log_warn "TERMINAL_THEME='${TERMINAL_THEME}' is not a known preset, falling back to 'dark'"
    TERMINAL_THEME="dark"
fi
export TERMINAL_THEME

log_info "Environment validated (PORT=${PORT} USERNAME=${USERNAME} TZ=${TZ} TERMINAL_THEME=${TERMINAL_THEME} SUDO_NOPASSWD=${SUDO_NOPASSWD} ENABLE_SSL=${ENABLE_SSL})"
