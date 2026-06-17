# Register (or update) all Kafka Connect connectors:
#   1. oracle-cdc-connector        (Debezium source: Oracle -> Kafka)
#   2. oracle-jdbc-sink-customers  (JDBC sink:  Kafka -> target Oracle)
#   3. oracle-jdbc-sink-orders
#   4. oracle-jdbc-sink-order-items
param(
    [string]$ConnectUrl = "http://localhost:8083"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$connectorFiles = @(
    "$root\kafka-connect\oracle-connector.json",
    "$root\kafka-connect\jdbc-sink-customers.json",
    "$root\kafka-connect\jdbc-sink-orders.json",
    "$root\kafka-connect\jdbc-sink-order-items.json"
)

Write-Host "=== Waiting for Kafka Connect REST API ===" -ForegroundColor Cyan
while ($true) {
    try {
        $null = Invoke-RestMethod -Uri "$ConnectUrl/connectors" -Method Get -TimeoutSec 5
        break
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
    }
}
Write-Host " ready"

foreach ($file in $connectorFiles) {
    $config   = Get-Content $file -Raw | ConvertFrom-Json
    $name     = $config.name
    $existing = $null
    try {
        $existing = Invoke-RestMethod -Uri "$ConnectUrl/connectors/$name" -Method Get
    } catch {}

    if ($existing) {
        Write-Host "=> Updating connector '$name'..." -ForegroundColor Yellow
        $body = $config.config | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri "$ConnectUrl/connectors/$name/config" `
            -Method Put `
            -ContentType "application/json" `
            -Body $body | Out-Null
    } else {
        Write-Host "=> Registering connector '$name'..." -ForegroundColor Yellow
        $body = $config | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri "$ConnectUrl/connectors" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body | Out-Null
    }

    Start-Sleep -Seconds 3
    $status = Invoke-RestMethod -Uri "$ConnectUrl/connectors/$name/status"
    $state  = $status.connector.state
    $color  = if ($state -eq "RUNNING") { "Green" } else { "Red" }
    Write-Host "   status: $state" -ForegroundColor $color
}

Write-Host "=== All connectors registered ===" -ForegroundColor Green
