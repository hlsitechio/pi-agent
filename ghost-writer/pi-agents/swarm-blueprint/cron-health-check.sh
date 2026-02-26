#!/bin/bash
# Check which cron agents actually ran in the last expected interval
# Reports missing/late agents

AGENTS_DIR="/mnt/bounty/Claude/pi-agents"
NOW=$(date +%s)
echo "=== CRON HEALTH CHECK — $(date -u) ==="

for agent_dir in "$AGENTS_DIR"/*/; do
  name=$(basename "$agent_dir")
  log="$agent_dir/state/cron.log"
  if [ -f "$log" ]; then
    last_mod=$(stat -c %Y "$log" 2>/dev/null || echo 0)
    age=$(( (NOW - last_mod) / 60 ))
    echo "$name: last cron output ${age}m ago"
  fi
done
