#!/usr/bin/env bash
# Deploy metadata to a Salesforce org (scratch org or sandbox)
set -euo pipefail

ORG_ALIAS="${1:-erp-demo}"

echo "==> Deploying to org: $ORG_ALIAS"
sf project deploy start --source-dir force-app --target-org "$ORG_ALIAS" --wait 10

echo "==> Assigning permission set"
sf org assign permset --name ERP_Integration_Developer --target-org "$ORG_ALIAS"

echo "==> Running Apex tests"
sf apex run test --target-org "$ORG_ALIAS" --code-coverage --result-format human --wait 10

echo "==> Deployment complete!"
