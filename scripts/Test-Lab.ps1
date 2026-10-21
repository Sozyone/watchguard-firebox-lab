function Get-LabIP($Interface) {
    Get-NetIPAddress `
        -InterfaceAlias $Interface `
        -AddressFamily IPv4 `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254*" } |
        Select-Object -First 1 -ExpandProperty IPAddress
}

$corp  = Get-LabIP "vEthernet (CORP)"
$mgmt  = Get-LabIP "vEthernet (MANAGEMENT)"
$guest = Get-LabIP "vEthernet (GUEST)"

Write-Host "=== CORP Internet ==="
curl.exe -s -o NUL --connect-timeout 5 --interface $corp https://example.com

if ($LASTEXITCODE -eq 0) {
    Write-Host "PASS - CORP Internet works"
}
else {
    Write-Host "FAIL - CORP Internet"
}

Write-Host "`n=== MANAGEMENT Firebox Web UI ==="
curl.exe -k -s -o NUL --connect-timeout 5 --interface $mgmt https://10.30.30.1:8080

if ($LASTEXITCODE -eq 0) {
    Write-Host "PASS - MANAGEMENT can reach Firebox Web UI"
}
else {
    Write-Host "FAIL - MANAGEMENT cannot reach Firebox Web UI"
}

Write-Host "`n=== GUEST Internet ==="
curl.exe -s -o NUL --connect-timeout 5 --interface $guest https://example.com

if ($LASTEXITCODE -eq 0) {
    Write-Host "PASS - GUEST Internet works"
}
else {
    Write-Host "FAIL - GUEST Internet"
}
