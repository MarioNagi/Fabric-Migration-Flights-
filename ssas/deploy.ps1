# =============================================================================
# ssas/deploy.ps1
# Deploys FlightAnalytics Tabular model to local SSAS and processes it.
# Requires SqlServer PowerShell module (Install-Module SqlServer).
# =============================================================================

$ErrorActionPreference = 'Stop'
$server      = 'localhost'
$bimPath     = Join-Path $PSScriptRoot 'FlightAnalytics\Model.bim'
$dbName      = 'FlightAnalytics'

if (-not (Get-Module -ListAvailable SqlServer)) {
    Write-Host 'Installing SqlServer module...' -ForegroundColor Yellow
    Install-Module SqlServer -Scope CurrentUser -Force -AllowClobber
}
Import-Module SqlServer

$bim = Get-Content $bimPath -Raw

$createDbTmsl = @"
{
  "createOrReplace": {
    "object": { "database": "$dbName" },
    "database": $bim
  }
}
"@

Write-Host "Deploying $dbName to $server..." -ForegroundColor Cyan
Invoke-ASCmd -Server $server -Query $createDbTmsl | Out-Null

$processTmsl = @"
{
  "refresh": {
    "type": "full",
    "objects": [ { "database": "$dbName" } ]
  }
}
"@

Write-Host "Processing $dbName (full)..." -ForegroundColor Cyan
Invoke-ASCmd -Server $server -Query $processTmsl | Out-Null

Write-Host "Done." -ForegroundColor Green
