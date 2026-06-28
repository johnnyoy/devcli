# devcli

A lean, portable Docker image with core dev tools plus **Claude Code** and **OpenClaw**. Run `devcli` in any folder and it launches Claude Code inside a container with that folder mounted as `/workspace`. Auth config persists across runs via your host home directory — log in once, use everywhere.

## What's inside

| Tool | Purpose |
|------|---------|
| Python 3.13 (slim-bookworm) | scripting / Python projects |
| Node.js 22 | required by both AI agents |
| build-essential | native module compilation |
| git, gh | version control and GitHub CLI |
| ripgrep, jq, make, curl, wget | everyday dev tools |
| **Claude Code** (`@anthropic-ai/claude-code`) | AI coding agent |
| **OpenClaw** (`openclaw`) | AI coding agent |

---

## Requirements

- **Docker** — Desktop (Windows/macOS) or Engine (Linux)
- **One of:** PowerShell, CMD, or bash (depending on platform)

---

## One-time setup

### Windows (PowerShell or CMD)

Open PowerShell in the `devcli` repo directory:

```powershell
.\make.ps1 install
```

This builds the image and adds `devcli\bin\` to your **user** PATH. Open a new terminal for the PATH change to take effect.

### macOS

```bash
make install
```

This builds the image and creates a symlink `~/.local/bin/devcli → bin/devcli`.

Ensure `~/.local/bin` is on your PATH (add to `~/.zshrc` if needed):

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Then open a new terminal.

### Linux

```bash
make install
```

Same as macOS. On native Linux (not Docker Desktop / WSL2), the Makefile automatically passes your host UID/GID as build args so the container user matches you and bind-mounted directories are accessible without permission errors.

Ensure `~/.local/bin` is on your PATH (add to `~/.bashrc` if needed):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### WSL2 (Windows Subsystem for Linux)

WSL2 can run `devcli` from either side:

**From Windows (CMD / PowerShell)** — use the `.cmd` launcher, same as native Windows:
```powershell
.\make.ps1 install    # from the devcli repo dir
devcli                # from any Windows folder
```

**From WSL bash** — use the bash launcher:
```bash
make install          # from the devcli repo dir
devcli                # from any WSL folder
```

The bash launcher detects WSL2 + Docker Desktop and skips the `--user` flag (Docker Desktop handles UID remapping).

---

## Daily use

Run `devcli` from **any folder**. It mounts that folder as `/workspace` inside the container.

### Windows (CMD or PowerShell)

```cmd
cd C:\Projects\myapp
devcli                       :: opens Claude Code
devcli bash                  :: opens a bash shell
devcli openclaw              :: opens OpenClaw
devcli claude --resume       :: pass flags through
```

### macOS / Linux / WSL bash

```bash
cd ~/projects/myapp
devcli                       # opens Claude Code
devcli bash                  # opens a bash shell
devcli openclaw              # opens OpenClaw
devcli claude --resume       # pass flags through
```

The container is ephemeral — it is removed automatically when you exit.

---

## Auth persistence

Your host `~/.claude`, `~/.openclaw`, and `~/.config/gh` are bind-mounted into every container. Log in once and you stay logged in. Nothing credential-related is stored in the image.

### Passing an API key via environment variable

**Windows CMD:**
```cmd
set ANTHROPIC_API_KEY=sk-ant-...
devcli
```

**Windows PowerShell:**
```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-..."
devcli
```

**macOS / Linux / WSL bash:**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
devcli
```

`GITHUB_TOKEN` and `GH_TOKEN` are also forwarded if set.

---

## OpenClaw gateway (background daemon)

The gateway runs as a separate detached container so you don't need a dedicated terminal. It uses `--restart unless-stopped`, so it comes back automatically after Docker restarts.

```bash
devcli gateway up       # start the background daemon
devcli gateway url      # print the tokenized dashboard URL
devcli gateway status   # confirm it is running
devcli gateway logs     # tail logs
devcli gateway down     # stop it
```

The gateway shares `~/.openclaw` with your interactive `devcli` sessions so they all use the same token.

**Windows CMD / PowerShell alternative** (from the repo dir):
```powershell
.\make.ps1 gateway up
.\make.ps1 gateway url
```

**macOS / Linux (from the repo dir):**
```bash
make gateway CMD=up
make gateway CMD=url
```

---

## Extra port mappings

By default, ephemeral containers expose no ports — this prevents conflicts when you run `devcli` in multiple folders simultaneously. Forward ports for a specific session with the `DEVCLI_PORTS` env var:

**Windows CMD:**
```cmd
set DEVCLI_PORTS=-p 8000:8000 -p 5173:5173
devcli bash
```

**Windows PowerShell:**
```powershell
$env:DEVCLI_PORTS = "-p 8000:8000 -p 5173:5173"
devcli bash
```

**macOS / Linux / WSL bash:**
```bash
DEVCLI_PORTS="-p 8000:8000 -p 5173:5173" devcli bash
```

---

## Control surface reference

Run from the `devcli` repo directory:

| Windows (`make.ps1`) | macOS / Linux (`make`) | What it does |
|----------------------|------------------------|--------------|
| `.\make.ps1 build` | `make build` | Build the image |
| `.\make.ps1 rebuild` | `make rebuild` | Force-rebuild, no cache (updates agents) |
| `.\make.ps1 install` | `make install` | Build + add to PATH (run once) |
| `.\make.ps1 install-path` | `make install-path` | PATH setup only |
| `.\make.ps1 uninstall-path` | `make uninstall-path` | Remove from PATH |
| `.\make.ps1 doctor` | `make doctor` | Print all tool versions |
| `.\make.ps1 gateway up` | `make gateway CMD=up` | Start gateway daemon |
| `.\make.ps1 gateway url` | `make gateway CMD=url` | Print dashboard URL |
| `.\make.ps1 gateway down` | `make gateway CMD=down` | Stop gateway daemon |

---

## Updating agents

Both agents are installed at `latest` by default. To pull the newest versions:

**Windows:**
```powershell
.\make.ps1 rebuild
```

**macOS / Linux:**
```bash
make rebuild
```

### Pinning specific versions

**Windows (PowerShell):**
```powershell
docker build -t devcli:latest `
    --build-arg CLAUDE_VERSION=1.2.3 `
    --build-arg OPENCLAW_VERSION=4.5.6 `
    -f .devcontainer/Dockerfile .
```

**macOS / Linux:**
```bash
docker build -t devcli:latest \
    --build-arg CLAUDE_VERSION=1.2.3 \
    --build-arg OPENCLAW_VERSION=4.5.6 \
    -f .devcontainer/Dockerfile .
```

---

## How it works

Each `devcli` call runs:

```
docker run --rm -it
  -v "$PWD:/workspace"           ← current folder becomes /workspace
  -v "$HOME/.claude:/home/dev/.claude"
  -v "$HOME/.openclaw:/home/dev/.openclaw"
  -v "$HOME/.config/gh:/home/dev/.config/gh"
  devcli:latest [your command or "claude" by default]
```

On native Linux the launcher also adds `--user "$(id -u):$(id -g)"` to match the host user, and the image is built with matching UID/GID args so permissions are consistent.
