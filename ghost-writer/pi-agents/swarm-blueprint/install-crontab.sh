#!/bin/bash
# Install the swarm crontab — preserves existing entries
# Usage: ./install-crontab.sh [--replace]

CRON_CONF="/mnt/bounty/Claude/pi-agents/swarm-blueprint/swarm-crontab.conf"

if [ "$1" = "--replace" ]; then
  # Replace swarm section only
  crontab -l 2>/dev/null | sed '/# === RAINKODE CYBEROPS/,/# === END SWARM ===/d' > /tmp/existing-cron
  cat /tmp/existing-cron "$CRON_CONF" | crontab -
  echo "[+] Swarm crontab replaced. $(crontab -l | grep -c '^\*\|^[0-9]') entries total."
else
  # Append (check if already installed)
  if crontab -l 2>/dev/null | grep -q "RAINKODE CYBEROPS"; then
    echo "[-] Swarm crontab already installed. Use --replace to update."
    exit 1
  fi
  (crontab -l 2>/dev/null; echo ""; cat "$CRON_CONF") | crontab -
  echo "[+] Swarm crontab installed. $(crontab -l | grep -c '^\*\|^[0-9]') entries total."
fi
