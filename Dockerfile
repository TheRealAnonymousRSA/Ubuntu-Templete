# syntax=docker/dockerfile:1
#
# TheRealAnonymousRSA-VPS
# A browser-based Ubuntu 24.04 terminal, powered by ttyd.
#
# Build:
#   docker build -t therealanonymousrsa-vps .
#
# The image installs ttyd from the project's official static release
# binaries (https://github.com/tsl0922/ttyd/releases) rather than compiling
# from source, keeping the image small and the build fast/reproducible.

FROM ubuntu:24.04

LABEL org.opencontainers.image.title="TheRealAnonymousRSA-VPS" \
      org.opencontainers.image.description="Browser-based Ubuntu 24.04 terminal powered by ttyd" \
      org.opencontainers.image.source="https://github.com/TheRealAnonymousRSA/TheRealAnonymousRSA-VPS" \
      org.opencontainers.image.licenses="MIT"

# Pin the ttyd release explicitly for reproducible builds. Verified working
# release: https://github.com/tsl0922/ttyd/releases/tag/1.7.7
ARG TTYD_VERSION=1.7.7

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------
# tzdata + locales are added on top of the requested package list because
# TZ handling and UTF-8 terminal rendering both depend on them being present.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        wget \
        git \
        nano \
        vim \
        htop \
        sudo \
        procps \
        net-tools \
        iproute2 \
        jq \
        zip \
        unzip \
        ca-certificates \
        openssh-client \
        tzdata \
        locales \
        tini \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# ttyd (statically-linked release binary, architecture-aware)
# ---------------------------------------------------------------------------
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) ttyd_arch="x86_64" ;; \
        arm64) ttyd_arch="aarch64" ;; \
        armhf) ttyd_arch="armhf" ;; \
        *) echo "Unsupported architecture for ttyd: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/ttyd \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttyd_arch}"; \
    chmod +x /usr/local/bin/ttyd; \
    /usr/local/bin/ttyd --version

# ---------------------------------------------------------------------------
# Project files
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
COPY start.sh /usr/local/bin/start.sh
COPY healthcheck.sh /healthcheck.sh
COPY VERSION /etc/vps-version
COPY assets/banner.txt /etc/vps-banner.txt
COPY scripts/user-setup.sh /usr/local/lib/vps/user-setup.sh
COPY scripts/sysinfo.sh /usr/local/lib/vps/sysinfo.sh
COPY scripts/banner.sh /usr/local/lib/vps/banner.sh
COPY scripts/status.sh /usr/local/lib/vps/status.sh
COPY scripts/update.sh /usr/local/lib/vps/update.sh
COPY scripts/version.sh /usr/local/lib/vps/version.sh
COPY scripts/profile.d/00-vps-shell.sh /etc/profile.d/00-vps-shell.sh

RUN chmod +x \
        /entrypoint.sh \
        /usr/local/bin/start.sh \
        /healthcheck.sh \
        /usr/local/lib/vps/user-setup.sh \
        /usr/local/lib/vps/sysinfo.sh \
        /usr/local/lib/vps/banner.sh \
        /usr/local/lib/vps/status.sh \
        /usr/local/lib/vps/update.sh \
        /usr/local/lib/vps/version.sh \
    && chmod 0644 /etc/profile.d/00-vps-shell.sh \
    && ln -sf /usr/local/lib/vps/status.sh   /usr/local/bin/status \
    && ln -sf /usr/local/lib/vps/update.sh   /usr/local/bin/update \
    && ln -sf /usr/local/lib/vps/banner.sh   /usr/local/bin/banner \
    && ln -sf /usr/local/lib/vps/version.sh  /usr/local/bin/version \
    && ln -sf /healthcheck.sh                /usr/local/bin/health

# ---------------------------------------------------------------------------
# Runtime defaults (all overridable via `docker run -e` / compose / PaaS envs)
# ---------------------------------------------------------------------------
ENV PORT=7681 \
    USERNAME=admin \
    TZ=UTC \
    SUDO_NOPASSWD=true \
    ENABLE_SSL=false

EXPOSE 7681

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["/healthcheck.sh"]

# tini runs as PID 1: it forwards signals to entrypoint.sh's process and
# reaps any zombie processes left behind by client shell sessions. Both
# entrypoint.sh and start.sh use `exec` for their final step, so the chain
# is tini (1) -> ttyd, with no extra wrapper process sitting in between by
# the time the terminal is actually serving connections.
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
