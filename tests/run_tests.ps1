# =============================================================================
# tests/run_tests.ps1
# Runs every .sql test in tests/sql/ against the local SQL Server.
# Exits non-zero on any failure. CI runs this.
# =============================================================================

$ErrorActionPreference = 'Stop'
$root      = Split-Path -Parent $PSScriptRoot
$testDir   = Join-Path $root 'tests\sql'
$failures  = 0
$tests     = Get-ChildItem -Path $testDir -Filter '*.sql' | Sort-Object Name

Write-Host "Running $($tests.Count) test(s)..." -ForegroundColor Cyan

foreach ($t in $tests) {
    Write-Host "`n--- $($t.Name) ---" -ForegroundColor Yellow
    $output = & sqlcmd -S localhost -E -C -i $t.FullName -b 2>&1
    $exit = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exit -ne 0) {
        Write-Host "FAIL: $($t.Name) (exit $exit)" -ForegroundColor Red
        $failures++
    }
}

Write-Host "`n==========================="
if ($failures -gt 0) {
    Write-Host "$failures test(s) FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests PASSED" -ForegroundColor Green
    exit 0
}
