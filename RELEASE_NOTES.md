# Release Notes - v0.6.0 "Kali Edition"

**TheRealAnonymousRSA VPS v0.6.0** moves the base image from Ubuntu
24.04 to Kali Linux Rolling, and tightens up the project's own visual
identity - a branded prompt, a friendly hostname display, a cleaner
system snapshot - while keeping everything from v0.5 that already
worked: the modular architecture, `tini` + `tmux`, structured logging,
startup validation, terminal themes, and the full `tra-*` command set.

This is a base-image swap and a branding pass, not a rewrite.

## Highlights

**Kali Linux Rolling under the hood.** Same architecture, same
commands, same tmux-backed session persistence - now with `apt`
pointed at Kali's rolling repository instead of Ubuntu's, giving you
one-command access to Kali's full tool ecosystem if and when you want
it. The base image itself installs nothing beyond what's listed in the
Dockerfile; nothing extra is pulled in automatically.

**A shell that feels like its own thing.** The login prompt now reads
`[TheRealAnonymousRSA] ~$` instead of `user@host:~$`, and the system
snapshot shows a fixed, friendly hostname instead of Docker's randomly
generated one. Purely cosmetic - `hostname` and `tra-about` still tell
you directly that this is a container if you ask.

**New default port: 8080.** `PORT` still defaults sensibly and is still
fully overridable; the number just changed from `7681`.

## What did *not* change, on request

Two things in the spec for this release were declined, and remain
declined regardless of anything else in this changelog:

- **No hardcoded credentials.** `PASSWORD` is still an environment
  variable you set yourself, with the random-generation fallback intact
  when you don't set one. There is no baked-in shared username/password.
- **No concealment of the container itself.** The branding above is
  cosmetic dressing, not an attempt to make the underlying reality
  undetectable to whoever is logged in.

## Upgrading from v0.5

- Every `tra-*` command, the `tmux`/`ttyd`/`tini` architecture, and the
  `src/` module layout are unchanged - this upgrade only touches the
  base image and the branding/display layer.
- Default `PORT` changed from `7681` to `8080`. If you pinned `7681`
  explicitly via the `PORT` environment variable, nothing changes for
  you; if you relied on the default, update your port mapping.
- Two fixes from the v0.5 patch cycle are included here: home directory
  ownership on volume-mounted setups, and environment-variable
  whitespace trimming (see `CHANGELOG.md` for details).

## Known limitations

- Kali's rolling repository moves faster than Ubuntu's LTS repos;
  package versions inside the container will drift over time the same
  way they would on any Kali installation. Run `tra-update` periodically.
- `tra-speedtest` remains a lightweight approximation, not a rigorous
  measurement.
- Multi-user accounts, the file manager, and the admin panel are not yet
  implemented - see `ROADMAP.md`.
