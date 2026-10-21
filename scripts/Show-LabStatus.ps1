$interfaces = @(
    "vEthernet (CORP)",
    "vEthernet (SERVERS)",
    "vEthernet (MANAGEMENT)",
    "vEthernet (GUEST)"
)

Write-Host "=== VLAN Interfaces ==="

Get-NetAdapter |
    Where-Object { $_.Name -in $interfaces } |
    Format-Table Name, Status, MacAddress, LinkSpeed

Write-Host "`n=== IPv4 Addresses ==="

Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.InterfaceAlias -in $interfaces -and
        $_.IPAddress -notlike "169.254*"
    } |
    Format-Table InterfaceAlias, IPAddress, PrefixLength
