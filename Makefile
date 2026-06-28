# =============================================================================
# devcli — control surface (GNU make, for macOS / Linux / WSL)
#
#   make install          build image + symlink devcli into ~/.local/bin
#   make build            build (or rebuild) the image
#   make install-path     symlink only
#   make uninstall-path   remove the symlink
#   make rebuild          force-rebuild with --no-cache
#   make doctor           print tool versions
# =============================================================================

HERE    := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
IMAGE   := devcli:latest
DOCKERFILE := $(HERE)/.devcontainer/Dockerfile
BIN_DIR := $(HERE)/bin
LOCAL_BIN := $(HOME)/.local/bin
LINK    := $(LOCAL_BIN)/devcli
DEVCLI  := $(BIN_DIR)/devcli

# On native Linux (not macOS, not WSL2+Docker Desktop), pass the host UID/GID
# as build args so the in-container dev user matches the host user and
# bind-mounted files are accessible without permission errors.
_is_native_linux := $(shell uname -s 2>/dev/null)
_wsl_check       := $(shell grep -qi "microsoft\|wsl" /proc/version 2>/dev/null && echo yes || echo no)
ifeq ($(_is_native_linux) $(strip $(_wsl_check)),Linux no)
  _UID_ARGS := --build-arg USER_UID=$(shell id -u) --build-arg USER_GID=$(shell id -g)
else
  _UID_ARGS :=
endif

.DEFAULT_GOAL := help

.PHONY: help build rebuild install install-path uninstall-path doctor

help: ## Show this help
	@echo "devcli control surface"
	@echo ""
	@echo "  make install          Build image and link devcli into ~/.local/bin"
	@echo "  make build            Build (or rebuild) the image"
	@echo "  make install-path     Symlink bin/devcli into ~/.local/bin (idempotent)"
	@echo "  make uninstall-path   Remove the symlink"
	@echo "  make rebuild          Force rebuild --no-cache (refreshes agents)"
	@echo "  make doctor           Print versions of all tools in the container"

build: ## Build the image
	docker build $(_UID_ARGS) -t $(IMAGE) -f $(DOCKERFILE) $(HERE)

rebuild: ## Force rebuild with --no-cache (refreshes agents to latest)
	docker build --no-cache $(_UID_ARGS) -t $(IMAGE) -f $(DOCKERFILE) $(HERE)

install-path: ## Symlink bin/devcli into ~/.local/bin
	@chmod +x $(DEVCLI)
	@mkdir -p $(LOCAL_BIN) $(HOME)/.claude $(HOME)/.pi $(HOME)/.config/gh
	@touch $(HOME)/.claude.json
	@if [ -L $(LINK) ]; then \
	    echo "Symlink already exists at $(LINK) — nothing to do."; \
	elif [ -e $(LINK) ]; then \
	    echo "A file already exists at $(LINK). Remove it manually if you want devcli there."; \
	    exit 1; \
	else \
	    ln -s $(DEVCLI) $(LINK); \
	    echo "Linked: $(LINK) -> $(DEVCLI)"; \
	fi
	@echo "Ensure ~/.local/bin is on your PATH (add to ~/.bashrc / ~/.zshrc if needed):"
	@echo '  export PATH="$$HOME/.local/bin:$$PATH"'

install: build install-path ## Build image and set up PATH link
	@echo ""
	@echo "Done. Open a new shell and run 'devcli' from any folder."

uninstall-path: ## Remove the symlink
	@if [ -L $(LINK) ]; then rm $(LINK) && echo "Removed: $(LINK)"; \
	else echo "No symlink at $(LINK)."; fi

doctor: ## Print versions of all tools in the container
	@docker run --rm $(IMAGE) bash -lc '\
	    printf "%-12s %s\n" "tool" "version"; \
	    printf "%-12s %s\n" "------------" "----------------------------"; \
	    printf "%-12s %s\n" "python"   "$$(python --version 2>&1)"; \
	    printf "%-12s %s\n" "pip"      "$$(pip --version 2>&1 | cut -d" " -f1-2)"; \
	    printf "%-12s %s\n" "node"     "$$(node --version)"; \
	    printf "%-12s %s\n" "npm"      "$$(npm --version)"; \
	    printf "%-12s %s\n" "git"      "$$(git --version | cut -d" " -f1-3)"; \
	    printf "%-12s %s\n" "gh"       "$$(gh --version | head -n1)"; \
	    printf "%-12s %s\n" "ripgrep"  "$$(rg --version | head -n1)"; \
	    printf "%-12s %s\n" "jq"       "$$(jq --version)"; \
	    printf "%-12s %s\n" "make"     "$$(make --version | head -n1)"; \
	    printf "%-12s %s\n" "claude"   "$$(claude --version 2>/dev/null || echo "not found")"; \
	    printf "%-12s %s\n" "pi"       "$$(pi --version 2>/dev/null || echo "not found")"; \
	'
