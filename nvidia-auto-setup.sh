#!/bin/bash
# NVIDIA Driver Auto-Setup Script
# Runs after each reboot until NVIDIA is fully installed

STAGE_FILE="$HOME/.nvidia-setup-stage"
LOG_FILE="$HOME/.nvidia-setup.log"

log() {
    echo "$(date): $1" >> "$LOG_FILE"
    echo "$1"
}

# Get current stage (0 = start, 1 = rpmfusion active, 2 = nvidia installing, 3 = done)
STAGE=$(cat "$STAGE_FILE" 2>/dev/null || echo "0")

log "=== NVIDIA Auto-Setup Stage $STAGE ==="

case $STAGE in
    0)
        # Check if RPM Fusion is now active
        if rpm -q rpmfusion-nonfree-release &>/dev/null; then
            log "RPM Fusion is active. Installing NVIDIA driver..."
            echo "1" > "$STAGE_FILE"
            
            # Install NVIDIA driver
            rpm-ostree install akmod-nvidia xorg-x11-drv-nvidia-cuda --reboot
            
            if [ $? -eq 0 ]; then
                log "NVIDIA driver queued. System will reboot..."
                echo "2" > "$STAGE_FILE"
            else
                log "ERROR: Failed to install NVIDIA driver"
                echo "error" > "$STAGE_FILE"
            fi
        else
            log "RPM Fusion not yet active. Waiting for next boot..."
        fi
        ;;
    
    2)
        # Check if NVIDIA driver is now installed
        if lsmod | grep -q nvidia; then
            log "SUCCESS! NVIDIA driver is loaded and working!"
            echo "3" > "$STAGE_FILE"
            
            # Clean up autostart
            rm -f ~/.config/autostart/nvidia-auto-setup.desktop
            
            # Show notification
            notify-send "NVIDIA Setup Complete" "Your Quadro M2000M is now active. Games should run properly!" 2>/dev/null
            
            log "Setup complete. Autostart removed."
        else
            # Driver installed but not loaded - might need one more reboot or check for issues
            log "NVIDIA packages installed but driver not loaded. Checking..."
            if rpm -q akmod-nvidia &>/dev/null; then
                log "akmod-nvidia is installed. Driver may still be building. Try rebooting once more."
                notify-send "NVIDIA Setup" "Driver installed. Please reboot one more time if needed." 2>/dev/null
                echo "3" > "$STAGE_FILE"
                rm -f ~/.config/autostart/nvidia-auto-setup.desktop
            fi
        fi
        ;;
    
    3)
        log "Setup already complete!"
        rm -f ~/.config/autostart/nvidia-auto-setup.desktop
        ;;
    
    error)
        log "Previous stage had an error. Manual intervention needed."
        notify-send "NVIDIA Setup Error" "Check ~/.nvidia-setup.log for details" 2>/dev/null
        ;;
esac
