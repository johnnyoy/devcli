# devcli — portable AI dev container
#
# Bundles core dev tools plus Claude Code and OpenClaw into a single image.
# Launched ephemerally per-folder: `devcli` mounts $PWD as /workspace and
# runs Claude Code by default.
FROM python:3.13-slim-bookworm

ARG NODE_MAJOR=22
ARG CLAUDE_VERSION=latest
ARG OPENCLAW_VERSION=latest
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false

# --- System packages --------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        make \
        curl \
        wget \
        ca-certificates \
        gnupg \
        build-essential \
        ripgrep \
        jq \
        less \
        procps \
        lsof \
        sudo \
        openssh-client \
        bash-completion \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js ----------------------------------------------------------------
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

# --- GitHub CLI -------------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- AI agents: Claude Code + OpenClaw -------------------------------------
RUN npm install -g \
        "@anthropic-ai/claude-code@${CLAUDE_VERSION}" \
        "openclaw@${OPENCLAW_VERSION}" \
    && npm cache clean --force

# --- Non-root developer user ------------------------------------------------
RUN if ! getent group "${USER_GID}" >/dev/null; then groupadd -g "${USER_GID}" dev; fi \
    && if ! getent passwd "${USER_UID}" >/dev/null; then \
         useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash dev; \
       fi \
    && DEV_USER="$(getent passwd ${USER_UID} | cut -d: -f1)" \
    && echo "${DEV_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-dev \
    && chmod 0440 /etc/sudoers.d/90-dev

# Pre-create bind-mount target dirs with correct ownership so Docker Desktop
# (and the host bind-mount) don't land as root-owned inside the container.
RUN mkdir -p \
        /home/dev/.claude \
        /home/dev/.openclaw \
        /home/dev/.config/gh \
        /workspace \
    && chown -R "${USER_UID}:${USER_GID}" /home/dev /workspace

USER ${USER_UID}:${USER_GID}

ENV HOME=/home/dev \
    NODE_OPTIONS=--max-old-space-size=5120

WORKDIR /workspace

COPY --chown=${USER_UID}:${USER_GID} .devcontainer/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
