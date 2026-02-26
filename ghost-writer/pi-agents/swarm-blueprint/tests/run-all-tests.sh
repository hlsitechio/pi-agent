#!/bin/bash
# Run All Swarm Tests
# Comprehensive validation of swarm infrastructure

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TESTS_DIR"

echo "======================================="
echo "   Pi Agent Swarm Test Suite"
echo "======================================="
echo ""

PASSED=0
FAILED=0
TOTAL=0

# Find all test scripts
test_scripts=$(ls test-*.sh 2>/dev/null)

if [ -z "$test_scripts" ]; then
  echo "[-] No test scripts found"
  exit 1
fi

# Run each test
for test in $test_scripts; do
  TOTAL=$((TOTAL + 1))
  echo "======================================="
  echo "Test $TOTAL: $test"
  echo "======================================="

  if ./"$test"; then
    echo "[+] PASSED: $test"
    PASSED=$((PASSED + 1))
  else
    echo "[-] FAILED: $test"
    FAILED=$((FAILED + 1))
  fi

  echo ""
  echo ""
done

echo "======================================="
echo "   Test Suite Complete"
echo "======================================="
echo "Total tests: $TOTAL"
echo "[+] Passed: $PASSED"
echo "[-] Failed: $FAILED"
echo "======================================="

if [ $FAILED -eq 0 ]; then
  echo "[+] ALL TESTS PASSED"
  exit 0
else
  echo "[!] SOME TESTS FAILED"
  exit 1
fi
