#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Kinoite System Enhancements
# Performance, Security, Reliability, Usability

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
section() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# ============================================================================
# PERFORMANCE
# ============================================================================

setup_performance() {
    section "Performance Enhancements"

    # 1. Btrfs compression (transparent, saves space + faster I/O)
    log "Enabling btrfs compression on /var/home..."
    cat << 'EOF'
# Add to /etc/fstab for /var/home:
# compress=zstd:1

# Or enable dynamically:
sudo btrfs property set /var/home compression zstd

# Recompress existing files:
sudo btrfs filesystem defragment -r -v -czstd /var/home
EOF

    # 2. I/O Scheduler optimization
    log "Checking I/O scheduler..."
    for disk in /sys/block/nvme*/queue/scheduler; do
        if [ -f "$disk" ]; then
            echo "Current: $(cat "$disk")"
            echo "For NVMe, 'none' is optimal (already hardware-managed)"
        fi
    done

    # 3. vm.swappiness tuning
    log "Current swappiness: $(cat /proc/sys/vm/swappiness)"
    cat << 'EOF'
# For 32GB RAM + zram, lower swappiness is fine:
# Create /etc/sysctl.d/99-performance.conf with:

vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5

# Better for interactive workloads
EOF

    # 4. earlyoom (prevent OOM freezes)
    log "Installing earlyoom..."
    cat << 'EOF'
rpm-ostree install earlyoom
# After reboot:
sudo systemctl enable --now earlyoom
EOF

    # 5. Ananicy-cpp (auto-nice for better responsiveness)
    log "Ananicy-cpp config..."
    cat << 'EOF'
# Ananicy-cpp provides automatic process priorities
# Install from COPR or build from source
# Gives priority to interactive apps over background tasks
EOF

    # 6. Profile-sync-daemon (move browser profiles to RAM)
    log "Profile-sync-daemon..."
    cat << 'EOF'
# Moves browser profiles to tmpfs, syncs periodically
# Faster browser, less SSD wear

flatpak install flathub com.github.graysky2.profile-sync-daemon
# Or as rpm-ostree layer if available
EOF
}

# ============================================================================
# SECURITY
# ============================================================================

setup_security() {
    section "Security Enhancements"

    # 1. DNS-over-TLS
    log "Enabling DNS-over-TLS..."
    cat << 'EOF'
# Edit /etc/systemd/resolved.conf:
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
FallbackDNS=1.1.1.1#cloudflare-dns.com
DNSOverTLS=yes
DNSSEC=yes
Cache=yes
CacheFromLocalhost=no

# Then:
sudo systemctl restart systemd-resolved
EOF

    # 2. Firewall hardening
    log "Firewall recommendations..."
    cat << 'EOF'
# Check current zone
sudo firewall-cmd --get-active-zones

# Set default zone to drop (stricter)
sudo firewall-cmd --set-default-zone=drop

# Allow only what you need
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=syncthing  # if using
sudo firewall-cmd --permanent --add-port=1714-1764/tcp  # KDE Connect
sudo firewall-cmd --permanent --add-port=1714-1764/udp  # KDE Connect
sudo firewall-cmd --reload
EOF

    # 3. Fail2ban alternative (sshguard)
    log "SSH protection..."
    cat << 'EOF'
# sshguard is lighter than fail2ban
rpm-ostree install sshguard
# After reboot:
sudo systemctl enable --now sshguard
EOF

    # 4. Flatpak permissions (Flatseal)
    log "Flatpak sandboxing..."
    cat << 'EOF'
flatpak install flathub com.github.tchx84.Flatseal
# Use Flatseal to audit and restrict app permissions
# Key things to check:
# - Filesystem access (many apps request full home)
# - Network access
# - Device access
EOF

    # 5. USBGuard (USB device allowlisting)
    log "USB security..."
    cat << 'EOF'
# Prevent rogue USB devices
rpm-ostree install usbguard
# After reboot, generate initial policy:
sudo usbguard generate-policy > /etc/usbguard/rules.conf
sudo systemctl enable --now usbguard
# Use: usbguard allow-device <id> / block-device <id>
EOF

    # 6. Automatic security updates
    log "Auto security updates..."
    cat << 'EOF'
# Enable auto-staging (already suggested earlier)
sudo sed -i 's/#AutomaticUpdatePolicy=none/AutomaticUpdatePolicy=stage/' /etc/rpm-ostreed.conf
rpm-ostree reload
sudo systemctl enable --now rpm-ostreed-automatic.timer
EOF
}

# ============================================================================
# RELIABILITY / BACKUP
# ============================================================================

setup_reliability() {
    section "Reliability & Backup"

    # 1. Btrfs snapshots with snapper
    log "Btrfs snapshots..."
    cat << 'EOF'
rpm-ostree install snapper

# After reboot, configure:
sudo snapper -c home create-config /var/home
sudo snapper -c home set-config TIMELINE_CREATE=yes
sudo snapper -c home set-config TIMELINE_CLEANUP=yes
sudo snapper -c home set-config NUMBER_LIMIT=10
sudo snapper -c home set-config TIMELINE_MIN_AGE=1800
sudo snapper -c home set-config TIMELINE_LIMIT_HOURLY=5
sudo snapper -c home set-config TIMELINE_LIMIT_DAILY=7
sudo snapper -c home set-config TIMELINE_LIMIT_WEEKLY=4
sudo snapper -c home set-config TIMELINE_LIMIT_MONTHLY=3

sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

# View snapshots: snapper -c home list
# Rollback file: snapper -c home undochange <id>..0 <file>
EOF

    # 2. Restic backup
    log "Restic backup setup..."
    mkdir -p "$HOME/.config/restic"
    cat > "$HOME/.config/restic/backup.sh" << 'EOF'
#!/usr/bin/env bash
# Restic backup script - customize REPO and PASSWORD

export RESTIC_REPOSITORY="sftp:user@backup-server:/backups/kinoite"
# Or: export RESTIC_REPOSITORY="s3:s3.amazonaws.com/bucket-name"
# Or: export RESTIC_REPOSITORY="/mnt/backup-drive/restic"

export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"

# What to backup
BACKUP_PATHS=(
    "$HOME/Documents"
    "$HOME/repos"
    "$HOME/.config"
    "$HOME/.local/share"
)

# What to exclude
EXCLUDES=(
    --exclude="*.cache*"
    --exclude="*/.cache/*"
    --exclude="*/node_modules/*"
    --exclude="*/target/*"
    --exclude="*/.git/objects/*"
    --exclude="*.tmp"
)

restic backup "${EXCLUDES[@]}" "${BACKUP_PATHS[@]}"
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
EOF
    chmod +x "$HOME/.config/restic/backup.sh"
    log "Restic backup script created at ~/.config/restic/backup.sh"

    # 3. SSD health monitoring
    log "SSD health monitoring..."
    cat << 'EOF'
# Check SSD health periodically
sudo smartctl -a /dev/nvme0n1
sudo smartctl -a /dev/nvme1n1

# Enable SMART monitoring service
sudo systemctl enable --now smartd

# Automated TRIM (should be enabled by default on Fedora)
sudo systemctl enable --now fstrim.timer
EOF

    # 4. Systemd journal persistence
    log "Journal persistence..."
    cat << 'EOF'
# Ensure logs survive reboots for debugging
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
EOF
}

# ============================================================================
# NETWORKING
# ============================================================================

setup_networking() {
    section "Networking Enhancements"

    # 1. Tailscale (mesh VPN)
    log "Tailscale setup..."
    cat << 'EOF'
rpm-ostree install tailscale

# After reboot:
sudo systemctl enable --now tailscaled
sudo tailscale up

# Benefits:
# - Access your machines from anywhere
# - Automatic NAT traversal
# - MagicDNS (machine-name.tailnet)
# - Funnel (expose services publicly)
EOF

    # 2. DNS caching
    log "Local DNS caching..."
    cat << 'EOF'
# systemd-resolved already provides caching
# Verify cache is working:
resolvectl statistics

# For more advanced DNS (ad blocking, etc.):
# Consider running AdGuard Home in container
nerdctl run -d --name adguard \
    -p 53:53/tcp -p 53:53/udp \
    -p 3000:3000 \
    -v adguard-work:/opt/adguardhome/work \
    -v adguard-conf:/opt/adguardhome/conf \
    adguard/adguardhome

# Then point systemd-resolved to 127.0.0.1
EOF

    # 3. Network optimization
    log "Network tuning..."
    cat << 'EOF'
# Add to /etc/sysctl.d/99-network.conf:

# TCP Fast Open
net.ipv4.tcp_fastopen=3

# BBR congestion control (better than cubic)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Increase network buffers
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# Apply: sudo sysctl --system
EOF

    # 4. WireGuard
    log "WireGuard VPN..."
    cat << 'EOF'
# WireGuard is built into the kernel
# Create config at /etc/wireguard/wg0.conf

# Start: sudo wg-quick up wg0
# Auto-start: sudo systemctl enable wg-quick@wg0
EOF
}

# ============================================================================
# USABILITY
# ============================================================================

setup_usability() {
    section "Usability Enhancements"

    # 1. Better fonts
    log "Font improvements..."
    cat << 'EOF'
rpm-ostree install \
    google-noto-fonts-common \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-sans-mono-fonts \
    jetbrains-mono-fonts \
    fira-code-fonts \
    cascadia-code-fonts \
    adobe-source-code-pro-fonts

# Better font rendering (already good on Fedora)
EOF

    # 2. KDE tweaks
    log "KDE recommendations..."
    cat << 'EOF'
# Install KDE apps as Flatpaks for better sandboxing:
flatpak install flathub \
    org.kde.kate \
    org.kde.kcalc \
    org.kde.okular \
    org.kde.gwenview

# Desktop effects:
# System Settings > Workspace Behavior > Desktop Effects
# Disable effects you don't use for better performance

# Compositor:
# For NVIDIA: Use "OpenGL 3.1" rendering backend
# Consider disabling "Vsync" if you have tearing issues

# Baloo file indexer:
# If search is slow, limit indexed folders:
balooctl config set folders "$HOME/Documents" "$HOME/repos"
EOF

    # 3. Clipboard manager
    log "Clipboard manager..."
    cat << 'EOF'
# KDE's Klipper is built-in, but you can enhance:
# System Settings > Shortcuts > Klipper
# Set convenient shortcut for clipboard history
EOF

    # 4. Application launcher
    log "App launcher enhancement..."
    cat << 'EOF'
flatpak install flathub com.raggesilver.Keypunch  # Quick launcher
# Or use KRunner (Alt+Space by default)

# For terminal launcher:
rpm-ostree install rofi  # Or install via distrobox
EOF

    # 5. Terminal enhancements
    log "Terminal setup..."
    cat << 'EOF'
# Starship prompt (cross-shell)
curl -sS https://starship.rs/install.sh | sh

# Add to ~/.bashrc or ~/.zshrc:
eval "$(starship init bash)"

# Better ls replacement
rpm-ostree install eza
alias ls='eza --icons'
alias ll='eza -la --icons'
alias tree='eza --tree --icons'
EOF
}

# ============================================================================
# MONITORING
# ============================================================================

setup_monitoring() {
    section "System Monitoring"

    # 1. btop (better htop)
    log "System monitor..."
    cat << 'EOF'
rpm-ostree install btop
# Or: flatpak install flathub com.github.hluk.CopyQ

# btop provides:
# - CPU, memory, disk, network graphs
# - Process management
# - GPU monitoring (NVIDIA support)
EOF

    # 2. Disk usage visualization
    log "Disk analysis..."
    cat << 'EOF'
flatpak install flathub org.gnome.baobab  # Disk Usage Analyzer
# Or CLI: ncdu (install in distrobox)
EOF

    # 3. System info
    log "System info tools..."
    cat << 'EOF'
rpm-ostree install fastfetch  # Modern neofetch alternative
# Run: fastfetch
EOF

    # 4. Journal monitoring
    log "Log monitoring..."
    cat << 'EOF'
# Real-time error monitoring:
journalctl -f -p err

# Boot messages:
journalctl -b -p warning

# Service-specific:
journalctl -u containerd --since "1 hour ago"
EOF
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    section "Enhancement Summary"

    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    RECOMMENDED ACTIONS                         ║
╠════════════════════════════════════════════════════════════════╣
║ PERFORMANCE:                                                   ║
║   □ Enable btrfs zstd compression                              ║
║   □ Add sysctl performance tuning                              ║
║   □ Install earlyoom                                           ║
║                                                                ║
║ SECURITY:                                                      ║
║   □ Enable DNS-over-TLS in resolved.conf                       ║
║   □ Install Flatseal and audit Flatpak permissions             ║
║   □ Consider USBGuard for USB security                         ║
║   □ Enable automatic security updates (staging)                ║
║                                                                ║
║ RELIABILITY:                                                   ║
║   □ Set up snapper for btrfs snapshots                         ║
║   □ Configure restic backups                                   ║
║   □ Verify fstrim.timer is enabled                             ║
║                                                                ║
║ NETWORKING:                                                    ║
║   □ Install Tailscale for mesh VPN                             ║
║   □ Enable BBR congestion control                              ║
║   □ Consider AdGuard Home for DNS filtering                    ║
║                                                                ║
║ USABILITY:                                                     ║
║   □ Install developer fonts                                    ║
║   □ Set up Starship prompt                                     ║
║   □ Install btop for monitoring                                ║
╚════════════════════════════════════════════════════════════════╝

rpm-ostree packages to install (one command):

rpm-ostree install \
    earlyoom \
    snapper \
    tailscale \
    btop \
    fastfetch \
    google-noto-sans-fonts \
    jetbrains-mono-fonts \
    fira-code-fonts

After reboot, enable services:

sudo systemctl enable --now earlyoom
sudo systemctl enable --now tailscaled
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
EOF
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-summary}" in
    performance) setup_performance ;;
    security) setup_security ;;
    reliability) setup_reliability ;;
    networking) setup_networking ;;
    usability) setup_usability ;;
    monitoring) setup_monitoring ;;
    all)
        setup_performance
        setup_security
        setup_reliability
        setup_networking
        setup_usability
        setup_monitoring
        print_summary
        ;;
    summary|*) print_summary ;;
esac
