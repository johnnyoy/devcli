#!/bin/bash
# Mark /workspace safe so git works on bind-mounted host directories owned
# by a different uid (common on Linux/macOS; harmless on Docker Desktop/Windows).
set -euo pipefail

# On native Linux with --user <non-1000>, HOME=/home/dev exists but is owned
# by UID 1000, so git can't write the global config there. Redirect to /tmp.
if [ ! -w "${HOME:-/home/dev}" ]; then
    export GIT_CONFIG_GLOBAL=/tmp/.gitconfig
fi

git config --global --get-all safe.directory 2>/dev/null | grep -Fxq /workspace \
    || git config --global --add safe.directory /workspace

# Authenticate gh CLI if GH_TOKEN or GITHUB_TOKEN is set.
# gh auth login --with-token writes into ~/.config/gh (bind-mounted from host)
# so the session persists across container runs.
# gh auth setup-git wires the git credential helper on top.
_gh_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -n "$_gh_token" ] && command -v gh >/dev/null 2>&1; then
    echo "$_gh_token" | gh auth login --with-token --hostname github.com 2>/dev/null || true
    gh auth setup-git --hostname github.com >/dev/null 2>&1 || true
fi
unset _gh_token

exec "$@"
