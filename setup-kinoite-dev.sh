#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Kinoite Developer Environment Setup
# Uses: nerdctl, distrobox, flatpak
# Follows: Hyperpolymath Language Policy (ReScript, Deno, Rust, Gleam)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}\n"; }

# Versions
NERDCTL_VERSION="2.2.1"
DENO_VERSION="latest"

# Directories
LOCAL_BIN="$HOME/.local/bin"
CONTAINERD_ROOT="$HOME/.local/share/containerd"
NERDCTL_DIR="$HOME/.local/share/nerdctl"

mkdir -p "$LOCAL_BIN" "$CONTAINERD_ROOT" "$NERDCTL_DIR"

# ============================================================================
# PHASE 1: rpm-ostree packages (minimal)
# ============================================================================
setup_rpm_ostree() {
    section "Phase 1: rpm-ostree Base Packages"

    local PACKAGES=(
        distrobox
        toolbox
        direnv
        fuse-overlayfs
        slirp4netns
        rootlesskit
        crun
    )

    log "Checking which packages need to be installed..."
    local TO_INSTALL=()
    for pkg in "${PACKAGES[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            TO_INSTALL+=("$pkg")
        fi
    done

    if [ ${#TO_INSTALL[@]} -eq 0 ]; then
        log "All base packages already installed"
    else
        warn "The following packages will be layered (requires reboot):"
        printf '  - %s\n' "${TO_INSTALL[@]}"
        echo
        read -p "Install now? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rpm-ostree install "${TO_INSTALL[@]}"
            warn "Reboot required. Run this script again after reboot."
            exit 0
        fi
    fi
}

# ============================================================================
# PHASE 2: nerdctl + containerd (rootless)
# ============================================================================
setup_nerdctl() {
    section "Phase 2: nerdctl + containerd (Rootless)"

    if command -v nerdctl &>/dev/null; then
        log "nerdctl already installed: $(nerdctl --version)"
        return 0
    fi

    local TARBALL="nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"
    local URL="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/${TARBALL}"

    log "Downloading nerdctl-full v${NERDCTL_VERSION}..."
    curl -fsSL "$URL" -o "/tmp/$TARBALL"

    log "Extracting to ~/.local/..."
    tar -xzf "/tmp/$TARBALL" -C "$HOME/.local" --strip-components=0

    # Ensure binaries are in PATH
    for bin in nerdctl containerd containerd-shim-runc-v2 buildkitd buildctl ctr; do
        if [ -f "$HOME/.local/bin/$bin" ]; then
            chmod +x "$HOME/.local/bin/$bin"
        fi
    done

    rm -f "/tmp/$TARBALL"
    log "nerdctl installed successfully"

    # Setup rootless containerd
    setup_rootless_containerd
}

setup_rootless_containerd() {
    log "Setting up rootless containerd..."

    # Create containerd config
    mkdir -p "$HOME/.config/containerd"
    cat > "$HOME/.config/containerd/config.toml" << 'EOF'
version = 2

[grpc]
  address = "/run/user/1000/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "crun"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun.options]
    BinaryName = "crun"
EOF

    # Create systemd user service for containerd
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/containerd.service" << EOF
[Unit]
Description=containerd container runtime (rootless)
After=network.target

[Service]
Type=notify
ExecStart=$HOME/.local/bin/containerd --config $HOME/.config/containerd/config.toml --root $CONTAINERD_ROOT --state $XDG_RUNTIME_DIR/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=default.target
EOF

    # Create buildkitd service
    cat > "$HOME/.config/systemd/user/buildkitd.service" << EOF
[Unit]
Description=BuildKit daemon (rootless)
After=containerd.service
Requires=containerd.service

[Service]
Type=simple
ExecStart=$HOME/.local/bin/buildkitd --oci-worker=false --containerd-worker=true --containerd-worker-addr=$XDG_RUNTIME_DIR/containerd/containerd.sock
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now containerd.service
    systemctl --user enable --now buildkitd.service

    log "Rootless containerd started"

    # Configure nerdctl to use rootless
    mkdir -p "$HOME/.config/nerdctl"
    cat > "$HOME/.config/nerdctl/nerdctl.toml" << EOF
address = "unix://$XDG_RUNTIME_DIR/containerd/containerd.sock"
namespace = "default"
cni_path = "$HOME/.local/libexec/cni"
EOF

    log "nerdctl configured for rootless operation"
}

# ============================================================================
# PHASE 3: Flatpak Apps
# ============================================================================
setup_flatpak() {
    section "Phase 3: Flatpak Developer Apps"

    # Ensure flathub is added
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    declare -A FLATPAK_APPS=(
        # IDEs & Editors
        ["com.vscodium.codium"]="VSCodium"
        ["dev.zed.Zed"]="Zed Editor"
        ["io.neovide.neovide"]="Neovide"

        # Container Tools
        ["io.podman_desktop.PodmanDesktop"]="Podman Desktop"

        # Database Tools
        ["io.dbeaver.DBeaverCommunity"]="DBeaver"
        ["org.sqlitebrowser.sqlitebrowser"]="SQLite Browser"

        # API Tools
        ["com.usebruno.Bruno"]="Bruno API Client"

        # Git Tools
        ["com.github.Murmele.Gittyup"]="Gittyup"

        # Design
        ["org.inkscape.Inkscape"]="Inkscape"

        # Productivity
        ["md.obsidian.Obsidian"]="Obsidian"
        ["com.logseq.Logseq"]="Logseq"
    )

    log "Installing Flatpak apps..."
    for app_id in "${!FLATPAK_APPS[@]}"; do
        local name="${FLATPAK_APPS[$app_id]}"
        if flatpak info "$app_id" &>/dev/null; then
            log "$name already installed"
        else
            log "Installing $name..."
            flatpak install -y flathub "$app_id" || warn "Failed to install $name"
        fi
    done
}

# ============================================================================
# PHASE 4: Distroboxes
# ============================================================================
setup_distroboxes() {
    section "Phase 4: Development Distroboxes"

    # Configure distrobox to use nerdctl
    mkdir -p "$HOME/.config/distrobox"
    cat > "$HOME/.config/distrobox/distrobox.conf" << 'EOF'
container_manager="nerdctl"
non_interactive="1"
skip_workdir="0"
container_always_pull="0"
EOF

    log "Distrobox configured to use nerdctl"

    declare -A BOXES=(
        ["dev"]="registry.fedoraproject.org/fedora-toolbox:43"
        ["rust"]="ghcr.io/toolbx-images/archlinux-toolbox:latest"
        ["js"]="registry.fedoraproject.org/fedora-toolbox:43"
        ["beam"]="registry.fedoraproject.org/fedora-toolbox:43"
        ["ocaml"]="registry.fedoraproject.org/fedora-toolbox:43"
    )

    for box in "${!BOXES[@]}"; do
        local image="${BOXES[$box]}"
        if distrobox list | grep -q "^$box "; then
            log "Distrobox '$box' already exists"
        else
            log "Creating distrobox '$box' from $image..."
            distrobox create --name "$box" --image "$image" --yes || warn "Failed to create $box"
        fi
    done
}

# ============================================================================
# PHASE 5: Toolchain Setup Scripts
# ============================================================================
create_toolchain_scripts() {
    section "Phase 5: Toolchain Setup Scripts"

    mkdir -p "$HOME/scripts/toolchains"

    # dev box setup
    cat > "$HOME/scripts/toolchains/setup-dev.sh" << 'DEVEOF'
#!/usr/bin/env bash
# General development tools for 'dev' distrobox
set -euo pipefail

sudo dnf install -y \
    git git-lfs tig delta \
    ripgrep fd-find bat eza zoxide fzf \
    jq yq-go \
    starship direnv \
    ShellCheck shfmt \
    htop btop \
    cmake ninja-build \
    sqlite

# Starship prompt
mkdir -p ~/.config
starship preset pure-preset -o ~/.config/starship.toml

echo "Dev toolbox ready!"
DEVEOF

    # js (ReScript/Deno) box setup
    cat > "$HOME/scripts/toolchains/setup-js.sh" << 'JSEOF'
#!/usr/bin/env bash
# ReScript + Deno environment (Hyperpolymath primary stack)
set -euo pipefail

# Deno (primary runtime per language policy)
curl -fsSL https://deno.land/install.sh | sh
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# Verify
deno --version

# ReScript via Deno
cat > ~/.local/bin/rescript << 'EOF'
#!/bin/sh
exec deno run -A npm:rescript "$@"
EOF
chmod +x ~/.local/bin/rescript

# Useful Deno tools
deno install -Agf --name=fresh https://deno.land/x/fresh/init.ts
deno install -Agf jsr:@anthropic-ai/claude-code

echo "ReScript + Deno environment ready!"
echo "Remember: NO npm/node/bun in production (per language policy)"
JSEOF

    # rust box setup
    cat > "$HOME/scripts/toolchains/setup-rust.sh" << 'RUSTEOF'
#!/usr/bin/env bash
# Rust development environment (Tauri, Dioxus, CLI tools)
set -euo pipefail

# Rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Components
rustup component add rust-analyzer clippy rustfmt rust-src

# Essential cargo tools
cargo install cargo-watch cargo-edit cargo-audit cargo-outdated cargo-deny
cargo install cargo-binstall  # Fast binary installs

# Framework CLIs
cargo binstall -y tauri-cli    # Tauri 2.0 for mobile
cargo binstall -y dioxus-cli   # Dioxus for native UI
cargo binstall -y trunk        # WASM bundler

# Useful tools
cargo binstall -y ripgrep fd-find bat eza zoxide
cargo binstall -y just         # Task runner
cargo binstall -y tokei        # Code stats
cargo binstall -y hyperfine    # Benchmarking

echo "Rust environment ready!"
RUSTEOF

    # beam (Gleam) box setup
    cat > "$HOME/scripts/toolchains/setup-beam.sh" << 'BEAMEOF'
#!/usr/bin/env bash
# Gleam + BEAM environment
set -euo pipefail

sudo dnf install -y erlang elixir rebar3

# Gleam
curl -fsSL https://gleam.run/install.sh | sh

# Add to path
export PATH="$HOME/.gleam/bin:$PATH"

# Verify
gleam --version

echo "Gleam + BEAM environment ready!"
BEAMEOF

    # ocaml box setup
    cat > "$HOME/scripts/toolchains/setup-ocaml.sh" << 'OCAMLEOF'
#!/usr/bin/env bash
# OCaml environment (for AffineScript compiler)
set -euo pipefail

sudo dnf install -y opam bubblewrap

# Initialize opam
opam init --bare -y
eval $(opam env)

# Create switch with latest OCaml
opam switch create default 5.2.0 -y
eval $(opam env)

# Essential packages
opam install -y \
    dune \
    merlin \
    ocaml-lsp-server \
    utop \
    odoc \
    ocamlformat

echo "OCaml environment ready!"
echo "Run 'eval \$(opam env)' in new shells"
OCAMLEOF

    chmod +x "$HOME/scripts/toolchains/"*.sh
    log "Toolchain setup scripts created in ~/scripts/toolchains/"
}

# ============================================================================
# PHASE 6: Container Services (via nerdctl compose)
# ============================================================================
create_compose_services() {
    section "Phase 6: Development Services (nerdctl compose)"

    mkdir -p "$HOME/.config/dev-services"

    cat > "$HOME/.config/dev-services/compose.yaml" << 'EOF'
# Development services via nerdctl compose
# Start: nerdctl compose -f ~/.config/dev-services/compose.yaml up -d
# Stop:  nerdctl compose -f ~/.config/dev-services/compose.yaml down

services:
  postgres:
    image: postgres:16-alpine
    container_name: dev-postgres
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: dev
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: dev-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes

  minio:
    image: minio/minio:latest
    container_name: dev-minio
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio-data:/data
    command: server /data --console-address ":9001"

  mailpit:
    image: axllent/mailpit:latest
    container_name: dev-mailpit
    ports:
      - "1025:1025"   # SMTP
      - "8025:8025"   # Web UI

  # Uncomment if needed:
  # mongodb:
  #   image: mongo:7
  #   container_name: dev-mongodb
  #   ports:
  #     - "27017:27017"
  #   volumes:
  #     - mongo-data:/data/db

volumes:
  postgres-data:
  redis-data:
  minio-data:
  # mongo-data:
EOF

    # Create helper scripts
    cat > "$HOME/.local/bin/dev-services" << 'EOF'
#!/usr/bin/env bash
# Manage development services
COMPOSE_FILE="$HOME/.config/dev-services/compose.yaml"

case "${1:-}" in
    up|start)
        nerdctl compose -f "$COMPOSE_FILE" up -d "${@:2}"
        ;;
    down|stop)
        nerdctl compose -f "$COMPOSE_FILE" down "${@:2}"
        ;;
    logs)
        nerdctl compose -f "$COMPOSE_FILE" logs -f "${@:2}"
        ;;
    ps|status)
        nerdctl compose -f "$COMPOSE_FILE" ps
        ;;
    *)
        echo "Usage: dev-services {up|down|logs|ps} [service...]"
        echo "Services: postgres, redis, minio, mailpit"
        ;;
esac
EOF
    chmod +x "$HOME/.local/bin/dev-services"

    log "Dev services compose file created"
    log "Use 'dev-services up' to start all services"
}

# ============================================================================
# PHASE 7: Shell Configuration
# ============================================================================
setup_shell_config() {
    section "Phase 7: Shell Configuration"

    # Add to PATH
    local PROFILE_ADDITIONS='
# Kinoite dev environment
export PATH="$HOME/.local/bin:$HOME/.deno/bin:$HOME/.cargo/bin:$PATH"
export CONTAINERD_ADDRESS="$XDG_RUNTIME_DIR/containerd/containerd.sock"

# direnv hook
eval "$(direnv hook bash)"

# nerdctl aliases
alias docker="nerdctl"
alias docker-compose="nerdctl compose"
'

    if ! grep -q "Kinoite dev environment" "$HOME/.bashrc" 2>/dev/null; then
        echo "$PROFILE_ADDITIONS" >> "$HOME/.bashrc"
        log "Added environment to ~/.bashrc"
    fi

    if [ -f "$HOME/.zshrc" ] && ! grep -q "Kinoite dev environment" "$HOME/.zshrc" 2>/dev/null; then
        echo "$PROFILE_ADDITIONS" >> "$HOME/.zshrc"
        log "Added environment to ~/.zshrc"
    fi

    # Create useful aliases
    cat > "$HOME/.local/bin/db" << 'EOF'
#!/usr/bin/env bash
# Quick distrobox entry
distrobox enter "${1:-dev}"
EOF
    chmod +x "$HOME/.local/bin/db"

    log "Shell configuration complete"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║       Kinoite Developer Environment Setup                ║"
    echo "║       nerdctl + distrobox + flatpak                       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Ensure ~/.local/bin is in PATH for this session
    export PATH="$HOME/.local/bin:$PATH"

    setup_rpm_ostree
    setup_nerdctl
    setup_flatpak
    setup_distroboxes
    create_toolchain_scripts
    create_compose_services
    setup_shell_config

    section "Setup Complete!"

    echo "Next steps:"
    echo "  1. Reboot if rpm-ostree packages were installed"
    echo "  2. Run toolchain setup in each distrobox:"
    echo "     distrobox enter dev && ~/scripts/toolchains/setup-dev.sh"
    echo "     distrobox enter js && ~/scripts/toolchains/setup-js.sh"
    echo "     distrobox enter rust && ~/scripts/toolchains/setup-rust.sh"
    echo "     distrobox enter beam && ~/scripts/toolchains/setup-beam.sh"
    echo "     distrobox enter ocaml && ~/scripts/toolchains/setup-ocaml.sh"
    echo "  3. Start dev services: dev-services up"
    echo "  4. Quick distrobox entry: db [boxname]"
    echo ""
    echo "Aliases available after shell restart:"
    echo "  docker     -> nerdctl"
    echo "  db         -> distrobox enter"
    echo "  dev-services -> manage postgres/redis/minio/mailpit"
}

# Run with optional phase selection
case "${1:-all}" in
    rpm-ostree) setup_rpm_ostree ;;
    nerdctl) setup_nerdctl ;;
    flatpak) setup_flatpak ;;
    distrobox) setup_distroboxes ;;
    toolchains) create_toolchain_scripts ;;
    services) create_compose_services ;;
    shell) setup_shell_config ;;
    all|*) main ;;
esac
