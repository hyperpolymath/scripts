#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Migrate large directories from /var/home to eclipse drive

set -euo pipefail

ECLIPSE="/run/media/hyper/eclipse"
HOME_DIR="/var/home/hyper"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# Check eclipse is mounted
check_eclipse() {
    if [ ! -d "$ECLIPSE" ]; then
        error "Eclipse drive not mounted at $ECLIPSE"
    fi
    log "Eclipse drive found: $(df -h "$ECLIPSE" | tail -1 | awk '{print $4}') free"
}

# ============================================================================
# PHASE 1: Clear safe caches (recoverable data)
# ============================================================================
clear_caches() {
    section "Phase 1: Clear Safe Caches"

    local saved=0

    # rclone cache (will rebuild as needed)
    if [ -d "$HOME_DIR/.cache/rclone" ]; then
        local size=$(du -sm "$HOME_DIR/.cache/rclone" 2>/dev/null | cut -f1)
        log "Clearing rclone cache (~${size}MB)..."
        rm -rf "$HOME_DIR/.cache/rclone"
        saved=$((saved + size))
    fi

    # debuginfod cache (debug symbols, rebuild on demand)
    if [ -d "$HOME_DIR/.cache/debuginfod_client" ]; then
        local size=$(du -sm "$HOME_DIR/.cache/debuginfod_client" 2>/dev/null | cut -f1)
        log "Clearing debuginfod cache (~${size}MB)..."
        rm -rf "$HOME_DIR/.cache/debuginfod_client"
        saved=$((saved + size))
    fi

    # Cabal cache (Haskell packages, will rebuild)
    if [ -d "$HOME_DIR/.cache/cabal" ]; then
        local size=$(du -sm "$HOME_DIR/.cache/cabal" 2>/dev/null | cut -f1)
        log "Clearing cabal cache (~${size}MB)..."
        rm -rf "$HOME_DIR/.cache/cabal"
        saved=$((saved + size))
    fi

    # pip cache
    if [ -d "$HOME_DIR/.cache/pip" ]; then
        local size=$(du -sm "$HOME_DIR/.cache/pip" 2>/dev/null | cut -f1)
        log "Clearing pip cache (~${size}MB)..."
        rm -rf "$HOME_DIR/.cache/pip"
        saved=$((saved + size))
    fi

    # Old thumbnails
    if [ -d "$HOME_DIR/.cache/thumbnails" ]; then
        find "$HOME_DIR/.cache/thumbnails" -type f -mtime +30 -delete 2>/dev/null || true
        log "Cleared old thumbnails"
    fi

    log "Total cache cleared: ~${saved}MB"
}

# ============================================================================
# PHASE 2: Move repos (if not already symlinked)
# ============================================================================
migrate_repos() {
    section "Phase 2: Migrate repos/"

    local src="$HOME_DIR/repos"
    local dest="$ECLIPSE/hyper/repos"

    if [ -L "$src" ]; then
        log "repos/ is already a symlink to: $(readlink "$src")"
        return 0
    fi

    if [ ! -d "$src" ]; then
        log "No repos/ directory found"
        return 0
    fi

    local size=$(du -sh "$src" 2>/dev/null | cut -f1)
    warn "Moving repos/ ($size) to eclipse..."
    echo "This may take a while for 47GB of data."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Skipping repos migration"
        return 0
    fi

    mkdir -p "$dest"

    # Use rsync for reliable transfer with progress
    rsync -avh --progress "$src/" "$dest/"

    # Verify and create symlink
    if [ -d "$dest" ]; then
        mv "$src" "${src}.backup"
        ln -s "$dest" "$src"
        log "repos/ migrated and symlinked"
        log "Backup at ${src}.backup - delete after verification"
    fi
}

# ============================================================================
# PHASE 3: Move container storage
# ============================================================================
migrate_containers() {
    section "Phase 3: Migrate Container Storage"

    local src="$HOME_DIR/.local/share/containers"
    local dest="$ECLIPSE/hyper/containers"

    if [ -L "$src" ]; then
        log "containers/ already symlinked to: $(readlink "$src")"
        return 0
    fi

    if [ ! -d "$src" ]; then
        log "No container storage found"
        return 0
    fi

    local size=$(du -sh "$src" 2>/dev/null | cut -f1)
    warn "Moving container storage ($size) to eclipse..."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Skipping container migration"
        return 0
    fi

    # Stop any running containers first
    podman stop -a 2>/dev/null || true
    nerdctl stop $(nerdctl ps -q) 2>/dev/null || true

    mkdir -p "$dest"
    rsync -avh --progress "$src/" "$dest/"

    if [ -d "$dest" ]; then
        mv "$src" "${src}.backup"
        ln -s "$dest" "$src"
        log "Container storage migrated and symlinked"
    fi
}

# ============================================================================
# PHASE 4: Move Documents
# ============================================================================
migrate_documents() {
    section "Phase 4: Migrate Documents"

    local src="$HOME_DIR/Documents"
    local dest="$ECLIPSE/hyper/Documents"

    if [ -L "$src" ]; then
        log "Documents/ already symlinked"
        return 0
    fi

    if [ ! -d "$src" ] || [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        log "Documents/ is empty or doesn't exist"
        return 0
    fi

    local size=$(du -sh "$src" 2>/dev/null | cut -f1)
    warn "Moving Documents/ ($size) to eclipse..."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    mkdir -p "$dest"
    rsync -avh --progress "$src/" "$dest/"

    if [ -d "$dest" ]; then
        mv "$src" "${src}.backup"
        ln -s "$dest" "$src"
        log "Documents/ migrated and symlinked"
    fi
}

# ============================================================================
# PHASE 5: Configure nerdctl/containerd storage
# ============================================================================
configure_container_storage() {
    section "Phase 5: Configure Container Storage Location"

    local dest="$ECLIPSE/hyper/containerd"
    mkdir -p "$dest"

    # Update containerd config
    mkdir -p "$HOME_DIR/.config/containerd"
    cat > "$HOME_DIR/.config/containerd/config.toml" << EOF
version = 2

root = "$dest"
state = "\$XDG_RUNTIME_DIR/containerd"

[grpc]
  address = "/run/user/1000/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "crun"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
  runtime_type = "io.containerd.runc.v2"
EOF

    # Update podman storage
    mkdir -p "$HOME_DIR/.config/containers"
    cat > "$HOME_DIR/.config/containers/storage.conf" << EOF
[storage]
driver = "overlay"
runroot = "\$XDG_RUNTIME_DIR/containers"
graphroot = "$ECLIPSE/hyper/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF

    log "Container storage configured to use eclipse drive"
    warn "Restart containerd/podman services to apply"
}

# ============================================================================
# PHASE 6: Move Flatpak data (optional, advanced)
# ============================================================================
migrate_flatpak_data() {
    section "Phase 6: Move Flatpak App Data (Optional)"

    local src="$HOME_DIR/.var/app"
    local dest="$ECLIPSE/hyper/flatpak-data"

    warn "Moving Flatpak app data is risky - apps may break"
    warn "Consider using 'flatpak override' instead for Steam library"

    # Better approach: Just Steam library
    if flatpak info com.valvesoftware.Steam &>/dev/null; then
        log "Configuring Steam to use eclipse for games..."
        cat << 'EOF'
# In Steam:
# 1. Settings > Storage > Add Library Folder
# 2. Select: /run/media/hyper/eclipse/SteamLibrary
# 3. Set as default for new installs
# 4. Move existing games via right-click > Properties > Move Install Folder
EOF
    fi
}

# ============================================================================
# PHASE 7: Move .local/share items
# ============================================================================
migrate_local_share() {
    section "Phase 7: Move Large .local/share Items"

    local items=(
        "alire:1.6G"
        "claude:2.2G"
    )

    for item in "${items[@]}"; do
        local name="${item%%:*}"
        local size="${item##*:}"
        local src="$HOME_DIR/.local/share/$name"
        local dest="$ECLIPSE/hyper/local-share/$name"

        if [ -L "$src" ]; then
            log "$name already symlinked"
            continue
        fi

        if [ ! -d "$src" ]; then
            continue
        fi

        warn "Move $name ($size) to eclipse?"
        read -p "[y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            continue
        fi

        mkdir -p "$(dirname "$dest")"
        rsync -avh --progress "$src/" "$dest/"

        if [ -d "$dest" ]; then
            mv "$src" "${src}.backup"
            ln -s "$dest" "$src"
            log "$name migrated and symlinked"
        fi
    done
}

# ============================================================================
# Summary
# ============================================================================
print_summary() {
    section "Migration Summary"

    echo "Space on home drive:"
    df -h /var/home | tail -1

    echo ""
    echo "Space on eclipse:"
    df -h "$ECLIPSE" | tail -1

    echo ""
    echo "Symlinks created:"
    find "$HOME_DIR" -maxdepth 3 -type l -exec ls -la {} \; 2>/dev/null | grep eclipse || echo "None"

    echo ""
    echo "Backup directories (delete after verification):"
    find "$HOME_DIR" -maxdepth 3 -name "*.backup" -type d 2>/dev/null || echo "None"

    cat << 'EOF'

Next steps:
1. Verify everything works correctly
2. Delete .backup directories to reclaim space:
   rm -rf ~/repos.backup
   rm -rf ~/.local/share/containers.backup
   rm -rf ~/Documents.backup
3. Restart containerd if container storage was migrated:
   systemctl --user restart containerd
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          Migrate Data to Eclipse Drive                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_eclipse

    echo "Current space usage:"
    df -h /var/home "$ECLIPSE" | tail -2
    echo ""

    clear_caches
    migrate_repos
    migrate_containers
    migrate_documents
    configure_container_storage
    migrate_flatpak_data
    migrate_local_share

    print_summary
}

case "${1:-all}" in
    cache) clear_caches ;;
    repos) migrate_repos ;;
    containers) migrate_containers ;;
    documents) migrate_documents ;;
    config) configure_container_storage ;;
    flatpak) migrate_flatpak_data ;;
    local) migrate_local_share ;;
    summary) print_summary ;;
    all|*) main ;;
esac
