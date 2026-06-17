# Compare row counts and spot-check data between source and target.
param(
    [string]$SrcContainer = "oracle-db",
    [string]$TgtContainer = "oracle-target",
    [string]$AppPwd       = "app_password"
)

function Invoke-Sql {
    param([string]$Container, [string]$ConnStr, [string]$Sql)
    $result = $Sql | docker exec -i $Container sqlplus -S $ConnStr
    return $result
}

$srcConn = "app_user/${AppPwd}@//localhost:1521/XEPDB1"
$tgtConn = "app_user/${AppPwd}@//localhost:1521/XEPDB1"

$tables = @("CUSTOMERS", "ORDERS", "ORDER_ITEMS")
$allMatch = $true

Write-Host "`n=== Replication Verification ===" -ForegroundColor Cyan
Write-Host ("{0,-20} {1,10} {2,10} {3,10}" -f "Table", "Source", "Target", "Match")
Write-Host ("-" * 55)

foreach ($table in $tables) {
    $countSql = "SET HEADING OFF FEEDBACK OFF`nSELECT COUNT(*) FROM app_user.$table;`nEXIT"

    $srcCount = (Invoke-Sql $SrcContainer $srcConn $countSql | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1).Trim()
    $tgtCount = (Invoke-Sql $TgtContainer $tgtConn $countSql | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1).Trim()

    $match = if ($srcCount -eq $tgtCount) { "YES" } else { "NO"; $allMatch = $false }
    $color = if ($match -eq "YES") { "Green" } else { "Red" }
    Write-Host ("{0,-20} {1,10} {2,10} {3,10}" -f $table, $srcCount, $tgtCount, $match) -ForegroundColor $color
}

Write-Host ""
if ($allMatch) {
    Write-Host "All tables match." -ForegroundColor Green
} else {
    Write-Host "Mismatch detected — replication may still be catching up." -ForegroundColor Yellow
    Write-Host "Wait a few seconds and re-run, or check: docker logs kafka-connect"
}

# Spot-check: print first 5 customers from each side
Write-Host "`n=== CUSTOMERS sample (source) ===" -ForegroundColor Cyan
$sampleSql = "SET PAGESIZE 20 LINESIZE 120 FEEDBACK OFF`nCOLUMN CUSTOMER_ID FORMAT 99`nCOLUMN FIRST_NAME FORMAT A12`nCOLUMN LAST_NAME FORMAT A12`nCOLUMN EMAIL FORMAT A30`nCOLUMN STATUS FORMAT A8`nSELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, STATUS FROM app_user.CUSTOMERS WHERE ROWNUM <= 5 ORDER BY CUSTOMER_ID;`nEXIT"
Invoke-Sql $SrcContainer $srcConn $sampleSql

Write-Host "`n=== CUSTOMERS sample (target) ===" -ForegroundColor Cyan
Invoke-Sql $TgtContainer $tgtConn $sampleSql
