#!/usr/bin/env bash

powershell.exe -NoProfile -Command '
$names = @("CORP","SERVERS","MANAGEMENT","GUEST")

Write-Host "=== Firebox-Lab vSwitch ==="
Get-VMSwitch -Name "Firebox-Lab"

Write-Host "`n=== VLAN Assignments ==="
Get-VMNetworkAdapterVlan -ManagementOS |
    Where-Object { $_.VMNetworkAdapterName -in $names } |
    Format-Table VMNetworkAdapterName, Mode, VlanList

Write-Host "`n=== Interfaces ==="
Get-NetAdapter |
    Where-Object { $_.Name -match "vEthernet \((CORP|SERVERS|MANAGEMENT|GUEST)\)" } |
    Format-Table Name, Status, MacAddress, LinkSpeed

Write-Host "`n=== IPv4 Addresses ==="
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -match "vEthernet \((CORP|SERVERS|MANAGEMENT|GUEST)\)" } |
    Format-Table InterfaceAlias, IPAddress, PrefixLength
'
