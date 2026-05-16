# =============================================================================
# tasks.ps1 — one-command operations for the project.
# Usage: .\tasks.ps1 <command>
# Commands: setup, load, cdc, observability, verify, ssas, all, clean
# =============================================================================

param([Parameter(Mandatory=$true)][string]$Command)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Run-Sql([string]$path) {
    Write-Host "→ $path" -ForegroundColor Cyan
    & sqlcmd -S localhost -E -C -i (Join-Path $root $path) -b
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed on $path" }
}

switch ($Command) {
    'setup' {
        Run-Sql 'sql_onprem/01_create_databases.sql'
        Run-Sql 'sql_onprem/02_create_staging.sql'
        Run-Sql 'sql_onprem/03_create_star_schema.sql'
    }
    'load' {
        Run-Sql 'sql_onprem/04_load_dimensions.sql'
        Run-Sql 'sql_onprem/05_load_fact.sql'
    }
    'cdc' {
        Run-Sql 'sql_onprem/10_enable_cdc.sql'
        Run-Sql 'sql_onprem/11_cdc_window_function.sql'
        Run-Sql 'sql_onprem/12_watermark_table.sql'
    }
    'observability' {
        Run-Sql 'sql_onprem/20_etl_runlog.sql'
        Run-Sql 'sql_onprem/21_dq_framework.sql'
        Run-Sql 'sql_onprem/22_reconciliation_view.sql'
    }
    'verify' {
        & (Join-Path $root 'tests\run_tests.ps1')
    }
    'ssas' {
        & (Join-Path $root 'ssas\deploy.ps1')
    }
    'all' {
        & $PSCommandPath setup
        & $PSCommandPath observability
        & $PSCommandPath load
        & $PSCommandPath cdc
        & $PSCommandPath verify
        & $PSCommandPath ssas
    }
    'clean' {
        Write-Host 'Dropping FlightData_Curated_v2...' -ForegroundColor Yellow
        & sqlcmd -S localhost -E -C -Q "IF DB_ID('FlightData_Curated_v2') IS NOT NULL DROP DATABASE FlightData_Curated_v2"
    }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Valid: setup, load, cdc, observability, verify, ssas, all, clean"
        exit 1
    }
}
