# Deploy metadata to a Salesforce org (scratch org or sandbox)
param(
    [string]$OrgAlias = "erp-demo"
)

Write-Host "==> Deploying to org: $OrgAlias"
sf project deploy start --source-dir force-app --target-org $OrgAlias --wait 10

Write-Host "==> Assigning permission set"
sf org assign permset --name ERP_Integration_Developer --target-org $OrgAlias

Write-Host "==> Running Apex tests"
sf apex run test --target-org $OrgAlias --code-coverage --result-format human --wait 10

Write-Host "==> Deployment complete!"
