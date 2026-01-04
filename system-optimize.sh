#!/bin/bash
# System Optimization Script for Fedora Kinoite
# Generated 2026-01-02

set -e

echo "=== System Optimization Script ==="
echo ""

# 1. Fix NVIDIA Driver
echo "[1/5] Fixing NVIDIA driver - blacklisting nouveau..."
rpm-ostree kargs --append=modprobe.blacklist=nouveau --append=rd.driver.blacklist=nouveau
echo "✓ Nouveau blacklisted (reboot required for NVIDIA to work)"
echo ""

# 2. Tighten Firewall
echo "[2/5] Tightening firewall..."
firewall-cmd --permanent --remove-port=1025-65535/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-port=1025-65535/udp 2>/dev/null || true
# Add only necessary ports
firewall-cmd --permanent --add-port=22000/tcp   # Syncthing
firewall-cmd --permanent --add-port=22000/udp   # Syncthing discovery
firewall-cmd --permanent --add-port=21027/udp   # Syncthing local discovery
firewall-cmd --permanent --add-port=1716/tcp    # KDE Connect
firewall-cmd --permanent --add-port=1716/udp    # KDE Connect
firewall-cmd --reload
echo "✓ Firewall tightened - only Syncthing and KDE Connect ports open"
echo ""

# 3. Vacuum Journal Logs
echo "[3/5] Vacuuming journal logs..."
journalctl --vacuum-size=500M
echo "✓ Journal logs reduced to 500MB"
echo ""

# 4. Disable Unnecessary Services
echo "[4/5] Disabling unnecessary services..."
systemctl disable --now ModemManager 2>/dev/null || true
systemctl mask qemu-guest-agent 2>/dev/null || true
echo "✓ ModemManager disabled, qemu-guest-agent masked"
echo ""

# 5. Apply Network Optimizations (BBR)
echo "[5/5] Applying network optimizations..."
cat > /etc/sysctl.d/99-network-performance.conf << 'EOF'
# BBR congestion control for better throughput
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Increase buffer sizes for high-speed networks
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3
EOF
sysctl -p /etc/sysctl.d/99-network-performance.conf
echo "✓ BBR congestion control and network buffers optimized"
echo ""

echo "=== Optimization Complete ==="
echo ""
echo "IMPORTANT: Reboot required for NVIDIA driver fix to take effect!"
echo "Run: systemctl reboot"
