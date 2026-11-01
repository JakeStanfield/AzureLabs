<#
  Deploys the cost guard to a subscription.
  Two passes: the first creates the automation account so a webhook URI can be
  generated; the second wires the webhook into the action group and budget.
#>
param(
    [string]$Subscription = 'Az104-Labs',
    [Parameter(Mandatory)][string]$AlertEmail,
    [int]$BudgetAmount = 10,
    [string]$Location = 'eastus'
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$api = 'api-version=2023-11-01'
$webhookApi = 'api-version=2015-10-31'

az account set --subscription $Subscription
$subId = az account show --query id -o tsv

Write-Host "Pass 1: core resources"
$out = az deployment sub create --name cost-guard-core --location $Location `
    --template-file "$here\main.bicep" `
    --parameters alertEmail=$AlertEmail budgetAmount=$BudgetAmount location=$Location `
    --query properties.outputs -o json | ConvertFrom-Json
if ($LASTEXITCODE) { throw 'Pass 1 deployment failed' }

$rg = $out.resourceGroupName.value
$aa = $out.automationAccountName.value
$aaUrl = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Automation/automationAccounts/$aa"
$runbook = 'Backup-And-Deallocate'

Write-Host "Uploading and publishing runbook"
az rest --method put --url "$aaUrl/runbooks/$runbook/draft/content?$api" `
    --headers 'Content-Type=text/powershell' --body "@$here\Backup-And-Deallocate.ps1" | Out-Null
az rest --method post --url "$aaUrl/runbooks/$runbook/publish?$api" | Out-Null
for ($i = 0; $i -lt 30; $i++) {
    $state = az rest --method get --url "$aaUrl/runbooks/${runbook}?$api" --query properties.state -o tsv
    if ($state -eq 'Published') { break }
    Start-Sleep -Seconds 5
}
if ($state -ne 'Published') { throw "Runbook did not publish (state: $state)" }

Write-Host "Creating webhook"
$webhookName = 'budget-shutdown'
az rest --method delete --url "$aaUrl/webhooks/${webhookName}?$webhookApi" 2>$null | Out-Null
$uri = az rest --method post --url "$aaUrl/webhooks/generateUri?$webhookApi" -o tsv
$body = @{
    name       = $webhookName
    properties = @{
        isEnabled  = $true
        uri        = $uri
        expiryTime = (Get-Date).ToUniversalTime().AddYears(5).ToString('o')
        runbook    = @{ name = $runbook }
    }
} | ConvertTo-Json -Depth 5 -Compress
$bodyFile = New-TemporaryFile
Set-Content -Path $bodyFile -Value $body -Encoding ascii
az rest --method put --url "$aaUrl/webhooks/${webhookName}?$webhookApi" --body "@$bodyFile" | Out-Null
Remove-Item $bodyFile

Write-Host "Pass 2: action group and budget"
az deployment sub create --name cost-guard-alerts --location $Location `
    --template-file "$here\main.bicep" `
    --parameters alertEmail=$AlertEmail budgetAmount=$BudgetAmount location=$Location webhookUri=$uri `
    -o none
if ($LASTEXITCODE) { throw 'Pass 2 deployment failed' }

Write-Host "Done. Template backups will land in storage account $($out.storageAccountName.value)."
