# syntax=docker/dockerfile:1
#
# TheRealAnonymousRSA VPS - v0.6.0 (Kali Edition)
# A browser-based Kali Linux Rolling terminal, powered by ttyd and tmux.
#
# Build:
#   docker build -t therealanonymousrsa-vps .

FROM kalilinux/kali-rolling

LABEL org.opencontainers.image.title="TheRealAnonymousRSA VPS" \
      org.opencontainers.image.description="Browser-based Kali Linux Rolling terminal powered by ttyd and tmux" \
      org.opencontainers.image.version="0.6.0" \
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
# The official kalilinux/kali-rolling image ships with no tools installed at
# all beyond a bare rootfs - everything below is explicitly requested, kept
# to what this project actually uses. tzdata, locales, iputils-ping, and
# traceroute are added on top of the original list because TZ handling,
# UTF-8 rendering, and the `ping`/`traceroute` utilities all depend on them
# being present and none of the four are in the base image.
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
        tmux \
        iputils-ping \
        traceroute \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Branded prompt for every future user
# ---------------------------------------------------------------------------
# /etc/profile.d/00-tra-shell.sh (installed below) sets PS1 too, but for a
# login shell (`su -`, which is what ttyd uses) that runs *before*
# ~/.profile sources ~/.bashrc - and the distro's default .bashrc sets its
# own PS1, silently overwriting ours. Appending our override to the skel
# file that `useradd -m` copies for every future user means it runs last
# in their .bashrc and actually wins. user-setup.sh applies the same fix
# at runtime for users that already existed before this fix shipped.
RUN printf '\n# TheRealAnonymousRSA VPS branded prompt\nPS1='"'"'[TheRealAnonymousRSA] \\w\\$ '"'"'\n' >> /etc/skel/.bashrc

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
# Project files - modular layout under /opt/tra, thin entrypoints at /
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
COPY start.sh /usr/local/bin/start.sh
COPY healthcheck.sh /healthcheck.sh
COPY VERSION /etc/tra-version

COPY src/core/         /opt/tra/core/
COPY src/terminal/     /opt/tra/terminal/
COPY src/system/       /opt/tra/system/
COPY src/branding/banner.sh  /opt/tra/branding/banner.sh
COPY src/branding/banner.txt /etc/tra-banner.txt
COPY src/commands/*.sh /opt/tra/commands/
COPY src/commands/profile.d/00-tra-shell.sh /etc/profile.d/00-tra-shell.sh
COPY config/themes.sh  /opt/tra/config/themes.sh

RUN chmod +x \
        /entrypoint.sh \
        /usr/local/bin/start.sh \
        /healthcheck.sh \
        /opt/tra/core/*.sh \
        /opt/tra/terminal/*.sh \
        /opt/tra/system/*.sh \
        /opt/tra/branding/banner.sh \
        /opt/tra/commands/*.sh \
        /opt/tra/config/themes.sh \
    && chmod 0644 /etc/profile.d/00-tra-shell.sh \
    && for f in /opt/tra/commands/tra-*.sh; do \
         name="$(basename "$f" .sh)"; \
         ln -sf "$f" "/usr/local/bin/${name}"; \
       done \
    && ln -sf /healthcheck.sh /usr/local/bin/tra-health

# ---------------------------------------------------------------------------
# Runtime defaults (all overridable via `docker run -e` / compose / PaaS envs)
# ---------------------------------------------------------------------------
ENV PORT=8080 \
    USERNAME=admin \
    TZ=UTC \
    SUDO_NOPASSWD=true \
    ENABLE_SSL=false \
    TERMINAL_THEME=dark

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["/healthcheck.sh"]

# tini runs as PID 1: it forwards signals to entrypoint.sh's process and
# reaps any zombie processes left behind by client shell sessions. Both
# entrypoint.sh and start.sh use `exec` for their final step, so the chain
# is tini (1) -> ttyd, with no extra wrapper process sitting in between by
# the time the terminal is actually serving connections.
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
