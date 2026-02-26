#!/bin/bash
# Test that Tier 2+ agents respect OPSEC red flag
# Tier 0-1 agents (OBSERVE/MONITOR) should still run
# Part of swarm hardening validation suite

echo "[*] Testing /tmp/opsec-red kill switch..."
echo "[*] Creating OPSEC red flag..."
touch /tmp/opsec-red

TIER0_PASS=0
TIER0_FAIL=0
TIER1_PASS=0
TIER1_FAIL=0
TIER2_PASS=0
TIER2_FAIL=0
NO_TIER_WARN=0

for agent_dir in /mnt/bounty/Claude/pi-agents/*/; do
  name=$(basename "$agent_dir")

  # Skip the blueprint itself
  [ "$name" = "swarm-blueprint" ] && continue

  run="$agent_dir/run.sh"
  [ ! -x "$run" ] && continue

  # Determine agent tier
  if grep -q "AGENT_TIER" "$run"; then
    tier=$(grep "^AGENT_TIER=" "$run" | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d ' ')

    # Handle string tiers (OBSERVE, MONITOR, etc)
    case "$tier" in
      OBSERVE) tier=0 ;;
      MONITOR) tier=1 ;;
      INTERACT) tier=2 ;;
      EXPLOIT) tier=3 ;;
      *) tier=$(echo "$tier" | grep -o '[0-9]' | head -1) ;;
    esac

    # If still not numeric, default to 0
    [[ ! "$tier" =~ ^[0-9]+$ ]] && tier=0
  else
    # No tier defined - these need to be updated but we'll warn
    echo "[!] $name: No AGENT_TIER defined (needs update)"
    NO_TIER_WARN=$((NO_TIER_WARN + 1))
    continue
  fi

  echo ""
  echo "[*] Testing: $name (Tier $tier)"

  # Run the agent with a short timeout
  output=$(timeout 10 "$run" 2>&1)
  exit_code=$?

  # Determine expected behavior
  should_halt=false
  [[ $tier -ge 2 ]] && should_halt=true

  # Check if the agent detected the OPSEC flag
  detected_opsec=false
  if echo "$output" | grep -qi "opsec\|red flag\|abort\|halt\|stopping"; then
    detected_opsec=true
  fi

  # Evaluate result based on tier
  if [ "$should_halt" = true ]; then
    # Tier 2+ should halt
    if [ "$detected_opsec" = true ] || [ $exit_code -ne 0 ]; then
      echo "[+] $name: HALTED correctly (Tier $tier)"
      TIER2_PASS=$((TIER2_PASS + 1))
    elif [ $exit_code -eq 124 ]; then
      echo "[-] $name: DID NOT HALT (Tier $tier agent ignored OPSEC flag)"
      TIER2_FAIL=$((TIER2_FAIL + 1))
    else
      echo "[!] $name: Unclear result (Tier $tier, exit $exit_code)"
      TIER2_FAIL=$((TIER2_FAIL + 1))
    fi
  else
    # Tier 0-1 should continue running
    if [ "$detected_opsec" = true ] && echo "$output" | grep -qi "halt\|abort\|stopping"; then
      echo "[-] $name: HALTED when it shouldn't (Tier $tier should keep running)"
      if [ $tier -eq 0 ]; then
        TIER0_FAIL=$((TIER0_FAIL + 1))
      else
        TIER1_FAIL=$((TIER1_FAIL + 1))
      fi
    else
      echo "[+] $name: Running correctly (Tier $tier continues during OPSEC red)"
      if [ $tier -eq 0 ]; then
        TIER0_PASS=$((TIER0_PASS + 1))
      else
        TIER1_PASS=$((TIER1_PASS + 1))
      fi
    fi
  fi
done

# Cleanup
rm -f /tmp/opsec-red
echo ""
echo "======================================="
echo "[*] OPSEC Red Flag Test Complete"
echo ""
echo "Tier 0 (OBSERVE) - should CONTINUE:"
echo "  [+] Passed: $TIER0_PASS"
echo "  [-] Failed: $TIER0_FAIL"
echo ""
echo "Tier 1 (MONITOR) - should CONTINUE:"
echo "  [+] Passed: $TIER1_PASS"
echo "  [-] Failed: $TIER1_FAIL"
echo ""
echo "Tier 2+ (INTERACT/EXPLOIT) - should HALT:"
echo "  [+] Passed: $TIER2_PASS"
echo "  [-] Failed: $TIER2_FAIL"
echo ""
echo "[!] Agents without tier definition: $NO_TIER_WARN"
echo "======================================="

TOTAL_FAIL=$((TIER0_FAIL + TIER1_FAIL + TIER2_FAIL))
if [ $TOTAL_FAIL -eq 0 ]; then
  echo "[+] ALL AGENTS RESPECT OPSEC RED CORRECTLY"
  exit 0
else
  echo "[!] SOME AGENTS DO NOT HANDLE OPSEC RED CORRECTLY"
  exit 1
fi
