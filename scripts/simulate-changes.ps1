# Fire DML changes on the SOURCE database to generate CDC events.
param(
    [string]$Container = "oracle-source",
    [string]$AppPwd   = "app_password"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "=== Running DML simulation on source ===" -ForegroundColor Cyan
Get-Content "$root\oracle\04_dml_simulation.sql" -Raw |
    docker exec -i $Container sqlplus -S "app_user/${AppPwd}@//localhost:1521/XEPDB1"

Write-Host "=== DML simulation complete ===" -ForegroundColor Green
Write-Host "Watch consumer:  docker logs -f oracle-cdc-consumer"
Write-Host "Then verify:     .\scripts\verify-replication.ps1"
