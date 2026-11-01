<#
  Triggered by the budget action group webhook.
  1. Exports an ARM template for every resource group to blob storage.
  2. Deallocates VMs / scale sets and stops App Service + Function apps.
#>
param([object]$WebhookData)

$ErrorActionPreference = 'Stop'
Connect-AzAccount -Identity | Out-Null

$storageAccount = Get-AutomationVariable -Name 'BackupStorageAccount'
$container = Get-AutomationVariable -Name 'BackupContainer'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$ctx = New-AzStorageContext -StorageAccountName $storageAccount -UseConnectedAccount
$tmp = Join-Path $env:TEMP $stamp
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

# --- Backup ---------------------------------------------------------------
foreach ($rg in Get-AzResourceGroup) {
    $name = $rg.ResourceGroupName
    try {
        $file = Join-Path $tmp "$name.json"
        Export-AzResourceGroup -ResourceGroupName $name -Path $file -IncludeParameterDefaultValue -Force -WarningAction SilentlyContinue | Out-Null
        Set-AzStorageBlobContent -File $file -Container $container -Blob "$stamp/$name.json" -Context $ctx -Force | Out-Null
        Write-Output "Exported $name -> $container/$stamp/$name.json"
    }
    catch {
        Write-Warning "Export failed for ${name}: $_"
    }
}

# --- Shutdown -------------------------------------------------------------
$ErrorActionPreference = 'Continue'

foreach ($vm in Get-AzVM -Status | Where-Object PowerState -ne 'VM deallocated') {
    Write-Output "Deallocating VM $($vm.ResourceGroupName)/$($vm.Name)"
    Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -NoWait | Out-Null
}

foreach ($vmss in Get-AzVmss) {
    Write-Output "Deallocating scale set $($vmss.ResourceGroupName)/$($vmss.Name)"
    Stop-AzVmss -ResourceGroupName $vmss.ResourceGroupName -VMScaleSetName $vmss.Name -Force -AsJob | Out-Null
}

foreach ($app in Get-AzWebApp | Where-Object State -eq 'Running') {
    Write-Output "Stopping web/function app $($app.ResourceGroup)/$($app.Name)"
    Stop-AzWebApp -ResourceGroupName $app.ResourceGroup -Name $app.Name | Out-Null
}

Write-Output "Cost guard run complete. Backups in $storageAccount/$container/$stamp/"
