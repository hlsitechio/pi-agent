#!/bin/bash
# Pi Binary Existence Check
# Sourced by Pi-based agents before launch
# Validates Pi CLI is installed and functional

PI_BIN="${HOME}/bin/pi"

# Check if Pi binary exists
if [ ! -f "$PI_BIN" ]; then
  echo "[-] Pi binary not found at $PI_BIN"
  echo "[-] Install Pi:"
  echo "    1. git clone https://github.com/anthropics/pi-mono"
  echo "    2. cd pi-mono"
  echo "    3. npm install"
  echo "    4. npm run build"
  echo "    5. Link to ~/bin: ln -s \$(pwd)/dist/pi ~/bin/pi"
  exit 1
fi

# Check if Pi binary is executable
if [ ! -x "$PI_BIN" ]; then
  echo "[-] Pi binary exists but is not executable: $PI_BIN"
  echo "[-] Fix permissions: chmod +x $PI_BIN"
  exit 1
fi

# Quick version check to ensure it's functional
if ! "$PI_BIN" --version > /dev/null 2>&1; then
  echo "[-] Pi binary found but not functional: $PI_BIN"
  echo "[-] Reinstall or rebuild Pi"
  exit 1
fi

# Get Pi version for logging
PI_VERSION=$("$PI_BIN" --version 2>&1 | head -1)

echo "[+] Pi binary OK: $PI_BIN"
echo "[+] Version: $PI_VERSION"

# Export for use by calling script
export PI_BIN
export PI_VERSION
