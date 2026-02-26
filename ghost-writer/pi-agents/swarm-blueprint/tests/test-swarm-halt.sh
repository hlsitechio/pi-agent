#!/bin/bash
# Test that ALL agents respect the global kill switch
# Part of swarm hardening validation suite

echo "[*] Testing /tmp/swarm-halt kill switch..."
echo "[*] Creating halt file..."
touch /tmp/swarm-halt

PASS=0
FAIL=0
AGENTS_TESTED=0

for agent_dir in /mnt/bounty/Claude/pi-agents/*/; do
  name=$(basename "$agent_dir")

  # Skip the blueprint itself
  [ "$name" = "swarm-blueprint" ] && continue

  run="$agent_dir/run.sh"
  [ ! -x "$run" ] && continue

  AGENTS_TESTED=$((AGENTS_TESTED + 1))
  echo ""
  echo "[*] Testing: $name"

  # Run the agent with a short timeout
  output=$(timeout 10 "$run" 2>&1)
  exit_code=$?

  # Check if the agent detected the halt file
  if echo "$output" | grep -qi "halt\|abort\|killed\|stopping\|emergency"; then
    echo "[+] $name: HALTED correctly"
    PASS=$((PASS + 1))
  elif [ $exit_code -eq 124 ]; then
    # Timeout means agent didn't halt - it kept running
    echo "[-] $name: DID NOT HALT (timeout)"
    FAIL=$((FAIL + 1))
  elif [ $exit_code -ne 0 ]; then
    # Agent exited with error - check if it was due to halt
    if echo "$output" | grep -qi "halt\|abort"; then
      echo "[+] $name: HALTED correctly (exit code $exit_code)"
      PASS=$((PASS + 1))
    else
      echo "[-] $name: DID NOT HALT (exited with code $exit_code but no halt message)"
      FAIL=$((FAIL + 1))
    fi
  else
    # Agent exited cleanly - might have finished before checking halt
    echo "[!] $name: Exited cleanly (may not have checked halt file)"
    FAIL=$((FAIL + 1))
  fi
done

# Cleanup
rm -f /tmp/swarm-halt
echo ""
echo "======================================="
echo "[*] Global Kill Switch Test Complete"
echo "[*] Agents tested: $AGENTS_TESTED"
echo "[+] Passed: $PASS"
echo "[-] Failed: $FAIL"
echo "======================================="

if [ $FAIL -eq 0 ]; then
  echo "[+] ALL AGENTS RESPECT GLOBAL HALT"
  exit 0
else
  echo "[!] SOME AGENTS DO NOT HALT CORRECTLY"
  exit 1
fi
