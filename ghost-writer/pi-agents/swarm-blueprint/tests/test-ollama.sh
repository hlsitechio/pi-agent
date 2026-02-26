#!/bin/bash
# Ollama Model Health Check
# Verifies Ollama service is running and models are functional
# Part of swarm infrastructure validation suite

echo "[*] Ollama Health Check Starting..."
echo ""

# Check if Ollama is running
echo "[*] Checking Ollama service..."
if ! curl -s --connect-timeout 5 http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "[-] CRITICAL: Ollama service not responding on localhost:11434"
  echo "[-] Start Ollama: systemctl start ollama"
  exit 1
fi
echo "[+] Ollama service is running"
echo ""

# List available models
echo "[*] Listing installed models..."
models_json=$(curl -s http://localhost:11434/api/tags)
if [ -z "$models_json" ]; then
  echo "[-] Failed to retrieve model list"
  exit 1
fi

# Parse model names
models=$(echo "$models_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print('\n'.join([m['name'] for m in data.get('models', [])]))")

if [ -z "$models" ]; then
  echo "[!] WARNING: No models installed"
  echo "[!] Install minimax: ollama pull minimax-m2.5:cloud"
  exit 1
fi

echo "[+] Installed models:"
echo "$models" | while read model; do
  echo "    - $model"
done
echo ""

# Test primary swarm model (minimax-m2.5:cloud)
SWARM_MODEL="minimax-m2.5:cloud"
echo "[*] Testing primary swarm model: $SWARM_MODEL"

if echo "$models" | grep -q "$SWARM_MODEL"; then
  echo "[+] $SWARM_MODEL is installed"

  # Quick inference test
  echo "[*] Running inference test..."
  test_prompt="Say 'OK' if you can read this"

  response=$(curl -s http://localhost:11434/api/generate -d "{
    \"model\": \"$SWARM_MODEL\",
    \"prompt\": \"$test_prompt\",
    \"stream\": false
  }")

  if [ $? -eq 0 ] && [ -n "$response" ]; then
    # Extract response text
    response_text=$(echo "$response" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('response', ''))" 2>/dev/null)

    if [ -n "$response_text" ]; then
      echo "[+] $SWARM_MODEL inference: SUCCESS"
      echo "    Response: ${response_text:0:100}"
    else
      echo "[-] $SWARM_MODEL inference: FAILED (empty response)"
    fi
  else
    echo "[-] $SWARM_MODEL inference: FAILED (connection error)"
  fi
else
  echo "[-] WARNING: $SWARM_MODEL NOT installed"
  echo "[-] Install: ollama pull $SWARM_MODEL"
fi
echo ""

# Test each installed model
echo "[*] Testing all installed models..."
WORKING_MODELS=0
BROKEN_MODELS=0

echo "$models" | while read model; do
  [ -z "$model" ] && continue

  echo -n "[*] Testing $model... "

  response=$(timeout 30 curl -s http://localhost:11434/api/generate -d "{
    \"model\": \"$model\",
    \"prompt\": \"test\",
    \"stream\": false
  }" 2>&1)

  if [ $? -eq 0 ] && echo "$response" | grep -q '"response"'; then
    echo "[+] OK"
    WORKING_MODELS=$((WORKING_MODELS + 1))
  else
    echo "[-] FAILED"
    BROKEN_MODELS=$((BROKEN_MODELS + 1))
  fi
done

echo ""
echo "======================================="
echo "[*] Ollama Health Check Complete"
echo "[+] Working models: $WORKING_MODELS"
echo "[-] Broken models: $BROKEN_MODELS"
echo "======================================="

if [ $BROKEN_MODELS -eq 0 ]; then
  echo "[+] ALL MODELS FUNCTIONAL"
  exit 0
else
  echo "[!] SOME MODELS ARE NOT WORKING"
  exit 1
fi
