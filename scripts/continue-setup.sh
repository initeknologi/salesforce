#!/usr/bin/env bash
# Continue setup after CLI auth is confirmed
set -euo pipefail

echo "Checking Salesforce CLI auth..."
if ! sf org auth list 2>/dev/null | grep -q .; then
  echo ""
  echo "CLI belum ter-auth. Login web sering timeout di Windows."
  echo ""
  echo "Cara cepat (Session ID dari browser):"
  echo "  1. Buka Developer Edition org di Chrome"
  echo "  2. F12 -> Application -> Cookies -> pilih domain salesforce"
  echo "  3. Copy value cookie 'sid'"
  echo "  4. Jalankan:"
  echo "     powershell -File scripts/login-with-token.ps1 -SessionId \"PASTE_SID_DISINI\""
  echo ""
  exit 1
fi

bash scripts/setup-local.sh
