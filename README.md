# TheRealAnonymousRSA-VPS

A self-hosted, browser-based Ubuntu 24.04 terminal, powered by [ttyd](https://github.com/tsl0922/ttyd), Docker, and `tini`. Open a tab, log in, get a real writable Bash shell with `sudo` -- no SSH client required.

[![Docker Build & Test](https://github.com/TheRealAnonymousRSA/TheRealAnonymousRSA-VPS/actions/workflows/docker.yml/badge.svg)](https://github.com/TheRealAnonymousRSA/TheRealAnonymousRSA-VPS/actions/workflows/docker.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- **Browser terminal** via ttyd 1.7.7, writable, backed by a real Bash login shell
- **Ubuntu 24.04 LTS** base with `curl`, `wget`, `git`, `nano`, `vim`, `htop`, `sudo`, `procps`, `net-tools`, `iproute2`, `jq`, `zip`, `unzip`, `ca-certificates`, `openssh-client`
- **`tini` as PID 1** for correct zombie reaping and signal forwarding, with `entrypoint.sh` and `start.sh` both `exec`-ing into the next step, so nothing sits between `tini` and `ttyd`
- **Automatic `$PORT`** support -- works with any platform that injects its own port
- **Secure-by-default login**: HTTP Basic Auth via ttyd's `--credential`, backed by a real Linux user with `sudo`; a strong random password is generated and printed once if you don't set one
- **Health checks** that actually check ttyd is answering, not just that the process exists
- **Helper commands**: `status`, `update`, `install`, `version`, `banner`, `health`
- **Optional built-in TLS** (`ENABLE_SSL=true`) for cases where you aren't terminating TLS at a reverse proxy

## A note on where to run this

This gives whoever logs in a full, `sudo`-capable Ubuntu shell over the browser. That's the point -- but it also means it's general-purpose compute, not a typical stateless web request/response app.

If you're looking at Railway, Render, or Northflank specifically because you want an **always-on free shell**, it's worth knowing how their free tiers behave in 2026 before you spend time on it:

- **Render's** free web services spin down after 15 minutes of inactivity and take 10-30 seconds to cold-start again on the next request -- a terminal you can't rely on staying connected isn't much of a VPS.
- **Railway** no longer has a permanent free tier; free usage is a one-time trial credit, then it's metered, paid compute. Running a persistent shell 24/7 burns through that fast.
- Most PaaS free/hobby tiers are priced and provisioned around bursty web traffic, not sustained general-purpose compute -- and several have suspended accounts for running exactly this "shell disguised as a web service" pattern.

None of that is a criticism of wanting a free personal Linux box -- it's a very reasonable thing to want. It just means the PaaS-free-tier route mostly doesn't get you there anymore, on top of usually being outside what those platforms' plans are meant for. For an always-on personal terminal, these tend to work better and are still cheap:

- A low-cost VPS (a few dollars a month covers this comfortably)
- A home server, NAS, or old laptop
- A Raspberry Pi
- Your own machine, via Docker Desktop, whenever you want it

The image is a completely ordinary Docker container either way -- it runs the same wherever Docker runs. If a specific platform's **paid** tier explicitly supports long-running background services, the same image works there too; just set the environment variables below in that platform's dashboard.

## Quick start (Docker)

```bash
docker build -t therealanonymousrsa-vps .

docker run -d \
  --name vps \
  -p 7681:7681 \
  -e USERNAME=admin \
  -e PASSWORD=change-me-please \
  -e TZ=UTC \
  therealanonymousrsa-vps
```

Open `http://localhost:7681`, log in with the username/password above, and you're in.

If you skip `-e PASSWORD=...`, one is generated for you -- check the logs once to grab it:

```bash
docker logs vps
```

## Docker Compose

```bash
cp config/.env.example .env
# edit .env: at minimum set a real PASSWORD
docker compose up -d
docker compose logs -f
```

`docker-compose.yml` maps `${PORT}` on the host to `${PORT}` in the container (both default to `7681`), and keeps `/home/${USERNAME}` in a named volume (`vps-home`) so your files survive a `docker compose down && up`.

## Deploying on your own VPS

This is the setup this project is really built for.

```bash
# on a fresh Ubuntu VPS, with Docker + the Compose plugin installed
git clone https://github.com/TheRealAnonymousRSA/TheRealAnonymousRSA-VPS.git
cd TheRealAnonymousRSA-VPS
cp config/.env.example .env
nano .env   # set PASSWORD, TZ, etc.
docker compose up -d
```

Then either:

- Put a reverse proxy (Caddy, nginx, or Traefik) in front of it on port 443 with a real certificate (recommended -- ttyd's Basic Auth sends credentials in the clear over plain HTTP), or
- Set `ENABLE_SSL=true`, `SSL_CERT_PATH`, and `SSL_KEY_PATH` to have ttyd terminate TLS itself.

Either way, only expose 443/TLS to the internet, not the raw HTTP port.

## Running on a PaaS anyway

If you're on a plan that genuinely supports a persistent background service (not a free/hobby web-service tier), the image works unmodified:

1. Point the platform at this repository (or push the built image to a registry it can pull from -- `.github/workflows/docker.yml` already publishes to GHCR on every push to `main`).
2. Set `USERNAME`, `PASSWORD`, and `TZ` as environment variables in the platform's dashboard. Leave `PORT` alone if the platform injects its own -- the container reads whatever it's given.
3. Point the platform's healthcheck at `/` on that port; a `200` or `401` response both mean ttyd is up.

Always check the current acceptable-use policy for whatever plan you're on -- pricing tiers and what's allowed on them change often.

## Environment variables

| Variable        | Default  | Description                                                                 |
|-----------------|----------|-------------------------------------------------------------------------------|
| `PORT`          | `7681`   | Port ttyd listens on. Most PaaS platforms inject this automatically.         |
| `USERNAME`      | `admin`  | Login username (ttyd Basic Auth) and the Linux user you land in.             |
| `PASSWORD`      | *(generated)* | Login password. If unset, a random 20-character password is generated and printed once in the logs. |
| `TZ`            | `UTC`    | IANA timezone name, e.g. `Africa/Johannesburg`, `Europe/London`.             |
| `SUDO_NOPASSWD` | `true`   | Whether the login user gets passwordless `sudo`.                             |
| `ENABLE_SSL`    | `false`  | Set `true` to have ttyd terminate TLS itself (requires the two variables below). |
| `SSL_CERT_PATH` | *(unset)* | Path (inside the container) to a TLS certificate. Required if `ENABLE_SSL=true`. |
| `SSL_KEY_PATH`  | *(unset)* | Path (inside the container) to the matching TLS private key. Required if `ENABLE_SSL=true`. |

## Commands

Available once you're logged into the terminal:

| Command   | Does |
|-----------|------|
| `status`  | System snapshot, who's logged in, whether ttyd and the healthcheck are OK |
| `update`  | `apt-get update && apt-get upgrade -y` |
| `install <pkg>` | Shorthand for `apt-get update && apt-get install -y <pkg>` |
| `version` | This project's version plus OS/kernel/ttyd versions |
| `banner`  | Re-prints the banner + system snapshot |
| `health`  | Runs the same check Docker's `HEALTHCHECK` uses, with output |

`install` is implemented as a shell function rather than a script on `PATH`, specifically so it doesn't shadow the real `/usr/bin/install` (coreutils) that build tools like `make install` rely on -- see the comment in `scripts/profile.d/00-vps-shell.sh` for the full reasoning.

## Security notes

- **Use a real password.** If you let one be generated, treat it as sensitive -- it's only printed once, in the logs.
- **Put TLS in front of this in production.** Plain HTTP Basic Auth sends your password in cleartext on the wire.
- **`sudo` means full root.** Whoever has the login credentials can do anything on the box, by design -- this is a personal single-user terminal, not a multi-tenant system.
- **The Docker socket is never mounted into this container**, and the image intentionally does not try to report the *host's* Docker Engine version for that reason. Mounting `/var/run/docker.sock` into a container that's reachable over the network hands anyone who can log in root-equivalent control of the host, which defeats the point of having a login at all.

## Troubleshooting

**Blank page / can't connect**
Check `docker logs <container>` for the actual bound port, confirm your `-p`/port mapping matches `$PORT`, and check any firewall between you and the host.

**I don't know my password**
Check `docker logs <container>` (or `docker compose logs`) for the one-time "no PASSWORD was set" banner near the start of the logs. If you've lost it entirely, restart the container with an explicit `-e PASSWORD=...`.

**Healthcheck shows `unhealthy`**
Run `docker logs <container>` and look for errors from ttyd itself. From inside the container (or via `docker exec`), `curl -v http://127.0.0.1:$PORT/` should return `200` or `401` -- anything else (connection refused, timeout) means ttyd isn't listening yet or crashed.

**Browser keeps asking for the password again**
That's the browser's Basic Auth cache expiring or being cleared, not a bug -- log in again with the same credentials.

**`sudo` asks for a password when I expected it not to**
`SUDO_NOPASSWD` was `false` (or a container from before you set it is still running with the old sudoers file). Recreate the container after setting `SUDO_NOPASSWD=true`.

**Terminal seems to hang instead of reconnecting cleanly after a restart**
This image deliberately avoids wrapping ttyd in a bash retry loop -- `tini` is PID 1, and both `entrypoint.sh` and `start.sh` `exec` into the next step, ending with `tini -> ttyd` directly. If the container restarts, `docker`'s own `restart: unless-stopped` (or your platform's equivalent) brings it back up cleanly; just reload the browser tab once it's back.

## Project structure

```
TheRealAnonymousRSA-VPS/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── start.sh
├── healthcheck.sh
├── VERSION
├── README.md
├── LICENSE
├── .gitignore
├── .dockerignore
├── config/
│   ├── .env.example
│   └── README.md
├── scripts/
│   ├── user-setup.sh
│   ├── sysinfo.sh
│   ├── banner.sh
│   ├── status.sh
│   ├── update.sh
│   ├── version.sh
│   └── profile.d/
│       └── 00-vps-shell.sh
├── assets/
│   └── banner.txt
└── .github/
    └── workflows/
        └── docker.yml
```

## License

MIT -- see [LICENSE](LICENSE).
