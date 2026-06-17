# Initialise the Oracle SOURCE database (oracle-db container).
# Run this after the container reports 'healthy'.
param(
    [string]$Container = "oracle-db",
    [string]$SysPwd   = "Oracle_1234",
    [string]$AppPwd   = "app_password"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Invoke-SqlFile {
    param([string]$File, [string]$ConnectStr)
    Write-Host "  => $File" -ForegroundColor Gray
    Get-Content $File -Raw | docker exec -i $Container sqlplus -S $ConnectStr
    if ($LASTEXITCODE -ne 0) { throw "sqlplus exited $LASTEXITCODE for $File" }
}

Write-Host "=== Waiting for oracle-db to become healthy ===" -ForegroundColor Cyan
while ((docker inspect --format="{{.State.Health.Status}}" $Container) -ne "healthy") {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 10
}
Write-Host " healthy"

Write-Host "=== CDC setup (sysdba -> CDB XE) ===" -ForegroundColor Cyan
Invoke-SqlFile "$root\oracle\01_cdc_setup.sql" "sys/${SysPwd}@//localhost:1521/XE as sysdba"

Write-Host "=== Schema (app_user -> XEPDB1) ===" -ForegroundColor Cyan
Invoke-SqlFile "$root\oracle\02_schema.sql" "app_user/${AppPwd}@//localhost:1521/XEPDB1"

Write-Host "=== Seed data (app_user -> XEPDB1) ===" -ForegroundColor Cyan
Invoke-SqlFile "$root\oracle\03_seed_data.sql" "app_user/${AppPwd}@//localhost:1521/XEPDB1"

Write-Host "=== Oracle SOURCE setup complete ===" -ForegroundColor Green
