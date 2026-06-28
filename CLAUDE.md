# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A lean Docker image (`devcli:latest`) plus host-side launchers. Running `devcli` from any folder mounts that folder as `/workspace` inside an ephemeral container and launches Claude Code by default. There is no docker-compose, no devcontainer.json — just `docker run --rm -it`.

## Build and install

**Windows (primary):**
```powershell
.\make.ps1 build          # build the image
.\make.ps1 install        # build + add bin\ to user PATH
.\make.ps1 rebuild        # force --no-cache rebuild (updates agents to latest)
.\make.ps1 doctor         # print all tool versions from inside the container
```

**macOS / Linux / WSL:**
```bash
make build
make install              # build + symlink bin/devcli into ~/.local/bin
make rebuild
make doctor
```

## Key files and their roles

- **`.devcontainer/Dockerfile`** — the image. Base is `python:3.13-slim-bookworm`; adds Node 22 (NodeSource), GitHub CLI, `build-essential`, and the two npm agents (`@anthropic-ai/claude-code`, `openclaw`). Container user is `dev` (UID/GID 1000 by default; overridable via `--build-arg USER_UID/USER_GID`). ENTRYPOINT is `entrypoint.sh`, CMD is `["claude"]`.
- **`.devcontainer/entrypoint.sh`** — runs inside the container on every start. Sets `git safe.directory /workspace`, optionally runs `gh auth setup-git`, then `exec "$@"`. Redirects `GIT_CONFIG_GLOBAL` to `/tmp/.gitconfig` when HOME is not writable (Linux `--user` scenario).
- **`bin/devcli`** — bash launcher (macOS / Linux / WSL). Handles the `gateway` subcommand, then does `docker run --rm -it -v "$PWD:/workspace" ...`. On native Linux (detected via `uname` + `/proc/version`) it adds `--user "$(id -u):$(id -g)"` so bind-mounted files are accessible.
- **`bin/devcli.cmd`** — Windows CMD launcher. Same logic as the bash launcher, using `%CD%` and `%USERPROFILE%`. Gateway management is implemented here via `goto` labels; `make.ps1 gateway` delegates to this file via `cmd /c`.
- **`make.ps1`** — PowerShell control surface for Windows. Wraps docker build, PATH manipulation, doctor, and gateway forwarding.
- **`Makefile`** — GNU make control surface for macOS/Linux/WSL. Detects native Linux at make-time and auto-adds `USER_UID`/`USER_GID` build args.

## Architecture: three moving parts

1. **Image** (`devcli:latest`) — built once, used for both interactive runs and the gateway daemon.
2. **Ephemeral interactive containers** — one per `devcli` invocation, `--rm`, bind-mounts `$PWD` as `/workspace` and host `~/.claude`, `~/.openclaw`, `~/.config/gh` for auth persistence.
3. **Gateway daemon** (`devcli-gateway`) — a single long-lived container started with `devcli gateway up`, `--restart unless-stopped`, exposes port 18789. Shares `~/.openclaw` with interactive containers so they use the same token.

## UID handling across platforms

| Platform | UID handling |
|----------|-------------|
| Windows Docker Desktop | Automatic remapping — no `--user` needed |
| macOS Docker Desktop | Automatic remapping — no `--user` needed |
| WSL2 + Docker Desktop | Detected via `/proc/version`; treated like Docker Desktop |
| Native Linux | `bin/devcli` adds `--user $(id -u):$(id -g)`; `Makefile` passes `USER_UID`/`USER_GID` to `docker build` |

## Agent version pinning

Both agents default to `latest`. To pin, pass build args:
```bash
docker build --build-arg CLAUDE_VERSION=1.2.3 --build-arg OPENCLAW_VERSION=4.5.6 \
    -t devcli:latest -f .devcontainer/Dockerfile .
```

## Auth dirs

`~/.claude`, `~/.openclaw`, `~/.config/gh` on the host are bind-mounted read-write into every container. These are never committed (`.gitignore`). `make nuke` / `docker volume prune` do not affect them — only manual deletion would.
