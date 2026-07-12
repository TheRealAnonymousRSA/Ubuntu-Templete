# config/

This directory holds configuration references for TheRealAnonymousRSA-VPS.

## `.env.example`

A fully-documented template for every environment variable the container
understands. Copy it to `.env` in the project root:

```bash
cp config/.env.example .env
```

`docker-compose.yml` loads `.env` automatically. `.env` itself is
git-ignored so you never accidentally commit a real password.

## Sudo access

There is no static sudoers file in this repository, because the sudoers
entry depends on `USERNAME`, which is only known at container start time.
Instead, `scripts/user-setup.sh` generates `/etc/sudoers.d/90-<username>`
*inside the running container* on every start, with `0440` permissions and
a `visudo -cf` syntax check before it is trusted. See that script for the
exact logic.
