#!/bin/bash
# Chain Trigger System
# Usage: source chain-trigger.sh; trigger_next <current-agent>
# Called at the end of an agent run to trigger downstream agents

CHAIN_CONFIG="/mnt/bounty/Claude/pi-agents/swarm-blueprint/chain-config.json"
TRIGGER_DIR="/tmp/swarm-triggers"
AGENTS_DIR="/mnt/bounty/Claude/pi-agents"

trigger_next() {
  local CURRENT="$1"
  local DATA="$2"  # Optional data file path

  mkdir -p "$TRIGGER_DIR"

  # Find what this agent triggers using python3 to parse JSON
  TARGETS=$(python3 -c "
import json
with open('$CHAIN_CONFIG') as f:
    config = json.load(f)
for chain in config['chains']:
    for step in chain['steps']:
        if step['agent'] == '$CURRENT':
            for t in step.get('triggers', []):
                print(t)
" 2>/dev/null)

  for target in $TARGETS; do
    # Create trigger file
    echo "{\"triggered_by\": \"$CURRENT\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"data\": \"$DATA\"}" > "$TRIGGER_DIR/$target.trigger"

    # Launch the target agent if its run.sh exists
    TARGET_RUN="$AGENTS_DIR/$target/run.sh"
    if [ -x "$TARGET_RUN" ]; then
      echo "[CHAIN] Triggering $target (from $CURRENT)"
      nohup "$TARGET_RUN" > "$AGENTS_DIR/$target/state/chain-run.log" 2>&1 &
    fi
  done
}

check_trigger() {
  local AGENT="$1"
  local TRIGGER_FILE="$TRIGGER_DIR/$AGENT.trigger"
  if [ -f "$TRIGGER_FILE" ]; then
    cat "$TRIGGER_FILE"
    rm -f "$TRIGGER_FILE"
    return 0
  fi
  return 1
}
