#!/usr/bin/env bash
# Full local setup: scratch org + deploy + permission set + tests
set -euo pipefail

ORG_ALIAS="${1:-erp-demo}"
DURATION_DAYS="${2:-7}"

echo "============================================"
echo " Salesforce ERP Integration Demo - Setup"
echo "============================================"
echo ""

# Check Dev Hub
if ! sf org list --json 2>/dev/null | grep -q '"isDevHub": true'; then
  echo "ERROR: No Dev Hub found."
  echo "Run this first:"
  echo "  sf org login web --set-default-dev-hub --alias DevHub"
  exit 1
fi

# Create scratch org (skip if already exists)
if sf org display --target-org "$ORG_ALIAS" &>/dev/null; then
  echo "==> Scratch org '$ORG_ALIAS' already exists, reusing..."
else
  echo "==> Creating scratch org '$ORG_ALIAS' (${DURATION_DAYS} days)..."
  sf org create scratch \
    --definition-file config/project-scratch-def.json \
    --alias "$ORG_ALIAS" \
    --set-default \
    --duration-days "$DURATION_DAYS"
fi

echo "==> Deploying metadata..."
sf project deploy start --source-dir force-app --target-org "$ORG_ALIAS" --wait 15

echo "==> Assigning permission set..."
sf org assign permset --name ERP_Integration_Developer --target-org "$ORG_ALIAS"

echo "==> Running Apex tests..."
sf apex run test --target-org "$ORG_ALIAS" --code-coverage --result-format human --wait 15

echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo " Open org:    sf org open --target-org $ORG_ALIAS"
echo " Mock ERP:    cd mock-erp && npm start  (port 3001)"
echo ""
echo " Next steps in Salesforce:"
echo "  1. Add 'Sales Orders' tab to your App"
echo "  2. Create an Account (e.g. Acme Corporation)"
echo "  3. Create Sales Order, set Status = Submitted"
echo "  4. Add 'erpOrderSyncPanel' LWC to record page"
echo "  5. Click 'Sync to ERP'"
echo ""
