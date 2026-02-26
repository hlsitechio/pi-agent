# Swarm Test Suite

Validation scripts for the Pi Agent Swarm infrastructure and governance framework.

## Test Scripts

### test-swarm-halt.sh
**Purpose:** Verify all agents respect the global kill switch
**Tests:** `/tmp/swarm-halt` flag
**Expected:** ALL agents should halt immediately when this flag is present
**Usage:** `./test-swarm-halt.sh`

Exit codes:
- `0` = All agents halted correctly
- `1` = Some agents failed to halt

### test-opsec-red.sh
**Purpose:** Verify tier-based OPSEC compliance
**Tests:** `/tmp/opsec-red` flag
**Expected:**
- Tier 0-1 (OBSERVE/MONITOR): Continue running
- Tier 2+ (INTERACT/EXPLOIT): Halt immediately

**Usage:** `./test-opsec-red.sh`

Exit codes:
- `0` = All agents behaved correctly for their tier
- `1` = Some agents failed tier-based behavior

### test-ollama.sh
**Purpose:** Verify Ollama service and model availability
**Tests:**
- Ollama service connectivity (localhost:11434)
- Model installation (minimax-m2.5:cloud)
- Inference functionality for all installed models

**Usage:** `./test-ollama.sh`

Exit codes:
- `0` = Ollama service running, all models functional
- `1` = Service down or models broken

## Library Scripts

### ../lib/check-pi.sh
**Purpose:** Validate Pi CLI binary before agent launch
**Checks:**
- Binary exists at `~/bin/pi`
- Binary is executable
- Binary is functional (version check)

**Usage:** `source /mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/check-pi.sh`

Pi-based agents should source this before launching.

## Running All Tests

```bash
# Run from tests directory
cd /mnt/bounty/Claude/pi-agents/swarm-blueprint/tests

# Run all tests
for test in test-*.sh; do
  echo "Running $test..."
  ./$test
  echo ""
done
```

## Continuous Integration

These tests should be run:
- Before deploying new agents
- After modifying governance framework
- Weekly as part of swarm health checks
- When troubleshooting agent behavior

## Test Development

When adding new tests:
1. Follow naming convention: `test-<feature>.sh`
2. Make executable: `chmod +x test-<feature>.sh`
3. Include clear pass/fail criteria
4. Return proper exit codes (0 = pass, 1 = fail)
5. Document in this README
