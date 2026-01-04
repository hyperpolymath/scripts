#!/bin/bash
# Run optimization and schedule reboot in 45 mins with 5-min warning

echo "=== Running system optimization ==="
~/system-optimize.sh

echo ""
echo "=== Scheduling reboot in 45 minutes ==="
echo "You'll get a warning 5 minutes before."

# Schedule the 5-minute warning (runs in 40 mins)
(sleep 40m && notify-send -u critical "⚠️ REBOOT IN 5 MINUTES" "System will reboot for NVIDIA driver activation" && wall "⚠️ System rebooting in 5 minutes for optimization") &

# Schedule the reboot (45 mins)
shutdown -r +45 "System optimization complete - rebooting for NVIDIA driver"

echo ""
echo "✓ Reboot scheduled for $(date -d '+45 minutes' '+%H:%M')"
echo "✓ Warning will appear at $(date -d '+40 minutes' '+%H:%M')"
echo ""
echo "To cancel: sudo shutdown -c"
