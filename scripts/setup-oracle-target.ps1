# Initialise the Oracle TARGET database (oracle-target container).
# Run this after the container reports 'healthy'.
param(
    [string]$Container = "oracle-target",
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

Write-Host "=== Waiting for oracle-target to become healthy ===" -ForegroundColor Cyan
while ((docker inspect --format="{{.State.Health.Status}}" $Container) -ne "healthy") {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 10
}
Write-Host " healthy"

Write-Host "=== Target user setup (sysdba -> CDB XE) ===" -ForegroundColor Cyan
Invoke-SqlFile "$root\oracle-target\01_target_setup.sql" "sys/${SysPwd}@//localhost:1521/XE as sysdba"

Write-Host "=== Target schema (app_user -> XEPDB1) ===" -ForegroundColor Cyan
Invoke-SqlFile "$root\oracle-target\02_target_schema.sql" "app_user/${AppPwd}@//localhost:1521/XEPDB1"

Write-Host "=== Oracle TARGET setup complete ===" -ForegroundColor Green
