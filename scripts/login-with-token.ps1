# Login Salesforce CLI via Session ID (workaround for AuthTimeoutError on Windows)
param(
    [Parameter(Mandatory=$true)]
    [string]$SessionId,
    [string]$InstanceUrl = "https://orgfarm-db45a47c65-dev-ed.develop.my.salesforce.com",
    [string]$Alias = "DevHub"
)

Write-Host "Authorizing CLI with access token..."
$SessionId | sf org login access-token `
    --instance-url $InstanceUrl `
    --alias $Alias `
    --set-default-dev-hub `
    --no-prompt

Write-Host ""
Write-Host "Verifying..."
sf org list --all

Write-Host ""
Write-Host "If Dev Hub shows above, run: powershell -File scripts/setup-local.ps1"
