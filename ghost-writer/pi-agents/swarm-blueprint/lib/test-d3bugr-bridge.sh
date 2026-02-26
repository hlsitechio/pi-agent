#!/bin/bash
# Test D3BUGR Bridge Functions
# Quick validation that the bridge can communicate with d3bugr service

set -e

echo "[*] Testing D3BUGR Bridge..."
echo ""

# Source the bridge
source "$(dirname "$0")/d3bugr-bridge.sh"

# Test 1: Health Check
echo "[1/3] Health check..."
STATUS=$(d3bugr_health)
if [ "$STATUS" = "200" ]; then
  echo "[+] D3BUGR is online (HTTP $STATUS)"
else
  echo "[-] D3BUGR returned HTTP $STATUS"
  exit 1
fi

# Test 2: Status endpoint
echo ""
echo "[2/3] Detailed status..."
d3bugr_status | jq -r '.status // "Status unavailable"' 2>/dev/null || echo "Status check completed"

# Test 3: List available tools
echo ""
echo "[3/3] Available tools..."
TOOLS=$(d3bugr_list_tools 2>/dev/null | jq -r '.tools[]' 2>/dev/null | head -5)
if [ -n "$TOOLS" ]; then
  echo "[+] Sample tools available:"
  echo "$TOOLS" | sed 's/^/  - /'
else
  echo "[i] Tools list endpoint not available (expected for some d3bugr versions)"
fi

echo ""
echo "[+] Bridge test complete!"
echo ""
echo "Available functions:"
echo "  - d3bugr_subfinder <domain>"
echo "  - d3bugr_httpx <targets>"
echo "  - d3bugr_nuclei <target> [severity]"
echo "  - d3bugr_nmap <target> [ports]"
echo "  - d3bugr_dalfox <url>"
echo "  - d3bugr_sqlmap <url>"
echo "  - d3bugr_ffuf <url> [wordlist]"
echo "  - d3bugr_katana <url> [depth]"
echo "  - d3bugr_dns_lookup <domain> [type]"
echo "  - d3bugr_harvest <domain>"
echo "  - d3bugr_shodan_ip <ip>"
echo "  - d3bugr_shodan_search <query>"
echo ""
echo "See D3BUGR-BRIDGE-README.md for full usage examples"
