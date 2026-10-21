$ErrorActionPreference = "Stop"

$corp    = (Get-NetIPAddress -InterfaceAlias "vEthernet (CORP)"       -AddressFamily IPv4).IPAddress
$servers = (Get-NetIPAddress -InterfaceAlias "vEthernet (SERVERS)"    -AddressFamily IPv4).IPAddress
$mgmt    = (Get-NetIPAddress -InterfaceAlias "vEthernet (MANAGEMENT)" -AddressFamily IPv4).IPAddress
$guest   = (Get-NetIPAddress -InterfaceAlias "vEthernet (GUEST)"      -AddressFamily IPv4).IPAddress

$passed = 0
$failed = 0

function Test-Tcp {
    param(
        [string]$SourceIP,
        [string]$DestinationIP,
        [int]$Port,
        [int]$TimeoutMs = 3000
    )

    $socket = [System.Net.Sockets.Socket]::new(
        [System.Net.Sockets.AddressFamily]::InterNetwork,
        [System.Net.Sockets.SocketType]::Stream,
        [System.Net.Sockets.ProtocolType]::Tcp
    )

    try {
        $local = [System.Net.IPEndPoint]::new(
            [System.Net.IPAddress]::Parse($SourceIP),
            0
        )

        $socket.Bind($local)

        $result = $socket.BeginConnect(
            $DestinationIP,
            $Port,
            $null,
            $null
        )

        if (-not $result.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            return $false
        }

        $socket.EndConnect($result)
        return $socket.Connected
    }
    catch {
        return $false
    }
    finally {
        $socket.Dispose()
    }
}

function Check-Tcp {
    param(
        [string]$Name,
        [string]$SourceIP,
        [string]$DestinationIP,
        [int]$Port,
        [bool]$ShouldConnect
    )

    $actual = Test-Tcp $SourceIP $DestinationIP $Port

    if ($actual -eq $ShouldConnect) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        $expected = if ($ShouldConnect) { "ALLOW" } else { "DENY" }
        Write-Host "[FAIL] $Name (expected $expected)" -ForegroundColor Red
        $script:failed++
    }
}

function Check-Web {
    param(
        [string]$Name,
        [string]$SourceIP,
        [string]$Url
    )

    & curl.exe `
        --interface $SourceIP `
        --connect-timeout 4 `
        --max-time 8 `
        -k `
        -s `
        -o NUL `
        $Url

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ""
Write-Host "=== WatchGuard Firebox Lab Tests ==="
Write-Host ""

Write-Host "CORP:       $corp"
Write-Host "SERVERS:    $servers"
Write-Host "MANAGEMENT: $mgmt"
Write-Host "GUEST:      $guest"
Write-Host ""

Check-Web "CORP -> Internet HTTPS allowed" `
    $corp "https://example.com"

Check-Web "MANAGEMENT -> Internet HTTPS allowed" `
    $mgmt "https://example.com"

Check-Web "GUEST -> Internet HTTPS allowed" `
    $guest "https://example.com"

Check-Tcp "MANAGEMENT -> Firebox Web UI allowed" `
    $mgmt "10.30.30.1" 8080 $true

Check-Tcp "MANAGEMENT -> Firebox SSH allowed" `
    $mgmt "10.30.30.1" 4118 $true

Check-Tcp "CORP -> Firebox Web UI denied" `
    $corp "10.10.10.1" 8080 $false

Check-Tcp "CORP -> Firebox SSH denied" `
    $corp "10.10.10.1" 4118 $false

Check-Tcp "SERVERS -> Firebox Web UI denied" `
    $servers "10.20.20.1" 8080 $false

Check-Tcp "SERVERS -> Firebox SSH denied" `
    $servers "10.20.20.1" 4118 $false

Check-Tcp "GUEST -> Firebox Web UI denied" `
    $guest "10.40.40.1" 8080 $false

Check-Tcp "GUEST -> Firebox SSH denied" `
    $guest "10.40.40.1" 4118 $false

Write-Host ""
Write-Host "=== Results ==="
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"

if ($failed -gt 0) {
    exit 1
}

exit 0
