# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.6.0] - "Kali Edition" - 2026-07-17

### Changed
- **Base image switched from `ubuntu:24.04` to `kalilinux/kali-rolling`.**
  The modular architecture, every `tra-*` command, `tmux` session
  persistence, `tini` as PID 1, and the ttyd-based terminal are
  unchanged - this is a base-image swap, not a rewrite. Kali's official
  image ships no tools by default, so the same explicit package list
  from v0.5 is installed the same way; all of it is available on
  Debian-family repos newer than Buster, which kali-rolling tracks.
- Default `PORT` changed from `7681` to `8080` (and `EXPOSE` to match).
- Branded interactive prompt (`[TheRealAnonymousRSA] \w\$`) replacing
  the default `user@host:~$` bash prompt.
- `sysinfo`'s `Hostname` line now shows a fixed friendly display name
  instead of Docker's randomly-generated container hostname, and the
  Docker-specific line is now a plain `Runtime : Container` rather than
  a longer explanation. Both are cosmetic only - `hostname` and
  `tra-about` still tell you directly that this is a container if you
  ask, on purpose (see Security notes in the README).
- `tra-about` now says explicitly that the banner/prompt/hostname are
  cosmetic branding over a real Docker container, for anyone who reads
  it looking for that confirmation.

### Fixed
- The branded prompt did not actually appear on login: Debian/Ubuntu's
  default `.bashrc` (copied into every new user via `useradd -m`) sets
  its own `PS1`, and for a login shell (`su -`, what ttyd uses), that
  runs *after* `/etc/profile.d` - so the distro default silently
  overwrote our prompt every time. Fixed at both the build-time skeleton
  (`/etc/skel/.bashrc`, for every future user) and at runtime in
  `user-setup.sh` (for users created before this fix existed, e.g. an
  in-place upgrade reusing the same home-directory volume).
Carried over from the v0.5.0-beta patch cycle, included in this release:
- `user-setup.sh` now explicitly takes ownership of the login user's home
  directory after `useradd`. When `/home/<username>` is provided by a
  mounted volume (e.g. the `vps-home` volume in `docker-compose.yml`),
  Docker creates it as an empty, root-owned directory *before* the
  entrypoint ever runs - `useradd -m` does not take ownership of a home
  directory that already exists, it just warns and leaves it as-is. Without
  this fix, the login user could not write to their own home directory.
- `bootstrap.sh` now trims whitespace/newlines from every environment
  variable before validating it. A value like `PORT` arriving with a
  trailing newline (something some platforms' env-injection can produce)
  was being rejected outright and silently replaced with the default port
  - ttyd would then listen on the wrong port while the platform kept
    routing traffic to the one it had actually assigned, with no obvious
    error anywhere in the logs.

### Not changed, despite being requested
A specification for this release asked for two things this project
will not do, independent of anything else: a hardcoded, shared
`TheRealAnonymousRSA` / `TRA` username and password baked into the
image (removing random-password generation and the `PASSWORD`
environment variable entirely), and making the container's true nature
undetectable to whoever is logged in (beyond the cosmetic branding
above). `PASSWORD` remains an environment variable you set yourself,
with the random-generation fallback intact when you don't, and
`tra-about`/`hostname` remain truthful about what this actually is.

## [0.5.0-beta] - 2026-07-13

### Added
- Modular architecture under `src/`: `core/`, `terminal/`, `system/`,
  `commands/`, `branding/`, plus theme presets in `config/themes.sh`.
- `tini` as PID 1 for correct signal forwarding and zombie reaping.
- Persistent terminal sessions via `tmux` - reconnecting (a dropped
  websocket, a browser refresh, a new tab) reattaches to the same
  session instead of starting a fresh shell.
- Structured logging (`src/core/logging.sh`): every core script now logs
  timestamped, leveled lines to both stdout and `/var/log/tra/system.log`.
- Startup dependency verification and environment validation
  (`src/core/bootstrap.sh`), with safe fallbacks and loud warnings
  instead of silent misbehavior on bad config.
- Four selectable terminal color themes (`TERMINAL_THEME`: `dark`,
  `light`, `solarized`, `dracula`), applied via ttyd's own documented
  `-t theme=` client option.
- Custom, fixed browser tab title via ttyd's `-t titleFixed=` option.
- Eleven `tra-*` commands: `tra-status`, `tra-update`, `tra-install`,
  `tra-network`, `tra-storage`, `tra-ip`, `tra-speedtest`, `tra-logs`,
  `tra-about`, `tra-version`, `tra-help`.
- One-command installer shortcuts inside `tra-install` for Node.js,
  Python, Git, Docker CLI, curl, FFmpeg, Nano, Vim, and build tools.
- `ping` and `traceroute` now installed and usable directly (previously
  absent from the base image).
- `ROADMAP.md` and `RELEASE_NOTES.md`.

### Changed
- All commands renamed with a `tra-` prefix. This also removed the need
  for the v0.1 `install` shell-function workaround (see Removed) - every
  command is now a uniquely-named script, since nothing collides with an
  existing coreutils binary anymore.
- `healthcheck.sh` documents explicitly why an absent tmux session right
  after startup is normal (it's created lazily on first connection) and
  is not treated as a failure.
- `entrypoint.sh` now *sources* `bootstrap.sh` rather than executing it
  as a subprocess, so validated/corrected environment variables actually
  propagate to the rest of the startup chain.
- `start.sh` is now a thin two-line delegator to
  `src/terminal/launch.sh`, kept at the repository root so existing
  deployments that reference `start.sh` directly keep working unchanged.

### Removed
- The v0.1 `install` bash-function workaround (no longer needed - see
  Changed).
- The flat `scripts/` and `assets/` directories, superseded by `src/`.

### Fixed
- `ping` and `traceroute` are genuinely installed now; on v0.1 the
  `net-tools`/`iproute2` package set did not actually provide either
  binary, so `tra-network`'s advertised tip ("ping and traceroute are
  ready to use") would have been false without this fix.
- `user-setup.sh` now creates `/etc/sudoers.d` if missing before writing
  into it, instead of assuming it already exists.

## [0.1.0-beta] - 2026-07-13

- Initial release: ttyd browser terminal on Ubuntu 24.04, Docker +
  Docker Compose, GitHub Actions build/test workflow, `status` /
  `update` / `install` / `version` / `banner` / `health` commands,
  environment-variable-driven login with auto-generated password
  fallback.
