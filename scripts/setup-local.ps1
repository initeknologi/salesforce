# Full local setup: scratch org + deploy + permission set + tests
param(
    [string]$OrgAlias = "erp-demo",
    [int]$DurationDays = 7
)

Write-Host "============================================"
Write-Host " Salesforce ERP Integration Demo - Setup"
Write-Host "============================================"
Write-Host ""

$orgList = sf org list --json | ConvertFrom-Json
$targetOrg = $OrgAlias
$authOrgs = sf org auth list --json 2>$null | ConvertFrom-Json
$hasAuth = $authOrgs.result -and $authOrgs.result.Count -gt 0

if (-not $hasAuth) {
    Write-Host "ERROR: No authenticated org found." -ForegroundColor Red
    Write-Host "Run this first:"
    Write-Host "  sf org login web --set-default-dev-hub --alias DevHub"
    exit 1
}

$devHubAlias = ($authOrgs.result | Where-Object { $_.isDefaultDevHubUsername -eq $true }).alias
if (-not $devHubAlias) { $devHubAlias = $authOrgs.result[0].alias }

try {
    sf org create scratch `
        --definition-file config/project-scratch-def.json `
        --alias $OrgAlias `
        --target-dev-hub $devHubAlias `
        --set-default `
        --duration-days $DurationDays 2>$null | Out-Null
    Write-Host "==> Scratch org '$OrgAlias' ready."
} catch {
    Write-Host "==> Scratch org unavailable (Dev Hub not enabled). Deploying to '$devHubAlias'..."
    $targetOrg = $devHubAlias
    sf config set target-org $targetOrg | Out-Null
}

Write-Host "==> Deploying metadata..."
sf project deploy start --source-dir force-app --target-org $targetOrg --wait 15

Write-Host "==> Assigning permission set..."
sf org assign permset --name ERP_Integration_Developer --target-org $targetOrg

Write-Host "==> Running Apex tests..."
sf apex run test --target-org $targetOrg --code-coverage --result-format human --wait 15

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Setup complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host " Open org:    sf org open --target-org $targetOrg"
Write-Host " Mock ERP:    cd mock-erp; npm start  (port 3001)"
Write-Host ""
