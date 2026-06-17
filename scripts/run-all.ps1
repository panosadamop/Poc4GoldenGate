# ============================================================
# run-all.ps1  —  End-to-end local setup
#
# Prerequisites (do these once before running this script):
#   1. docker login container-registry.oracle.com
#   2. Place ojdbc11.jar at kafka-connect\ojdbc11.jar
#      Download: https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html
#
# What this script does:
#   Step 1  Build images and start all Docker services
#   Step 2  Initialise the Oracle SOURCE DB (CDC user, schema, seed data)
#   Step 3  Initialise the Oracle TARGET DB (app user + empty tables)
#   Step 4  Register all Kafka Connect connectors
#   Step 5  Fire demo DML on source (triggers CDC events)
#   Step 6  Wait for replication and verify row counts match
# ============================================================
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Step {
    param([int]$N, [string]$Label)
    Write-Host "`n$('=' * 60)" -ForegroundColor Magenta
    Write-Host "  STEP $N — $Label" -ForegroundColor Magenta
    Write-Host "$('=' * 60)" -ForegroundColor Magenta
}

# ----------------------------------------------------------
Step 1 "Build images and start all services"
# ----------------------------------------------------------
Set-Location $root
docker-compose up --build -d
if ($LASTEXITCODE -ne 0) { throw "docker-compose up failed" }
Write-Host "Services starting. Oracle needs ~2-3 min on first run." -ForegroundColor Yellow

# ----------------------------------------------------------
Step 2 "Initialise Oracle SOURCE database"
# ----------------------------------------------------------
& "$root\scripts\setup-oracle-source.ps1"

# ----------------------------------------------------------
Step 3 "Initialise Oracle TARGET database"
# ----------------------------------------------------------
& "$root\scripts\setup-oracle-target.ps1"

# ----------------------------------------------------------
Step 4 "Register Kafka Connect connectors"
# ----------------------------------------------------------
& "$root\scripts\register-connectors.ps1"

Write-Host "`nSnapshot in progress — Debezium is reading existing rows..." -ForegroundColor Yellow
Write-Host "Watching consumer output (10 s)..."
Start-Sleep -Seconds 10

# ----------------------------------------------------------
Step 5 "Fire DML changes on source"
# ----------------------------------------------------------
& "$root\scripts\simulate-changes.ps1"

Write-Host "`nWaiting 15 s for events to propagate through Kafka to target..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# ----------------------------------------------------------
Step 6 "Verify replication"
# ----------------------------------------------------------
& "$root\scripts\verify-replication.ps1"

Write-Host "`n$('=' * 60)" -ForegroundColor Green
Write-Host "  END-TO-END SETUP COMPLETE" -ForegroundColor Green
Write-Host "$('=' * 60)" -ForegroundColor Green
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  docker logs -f oracle-cdc-consumer      # watch CDC events"
Write-Host "  .\scripts\simulate-changes.ps1          # fire more DML"
Write-Host "  .\scripts\verify-replication.ps1        # re-check counts"
Write-Host "  http://localhost:8080                   # Kafka UI"
Write-Host "  http://localhost:8083/connectors        # Connect REST API"
