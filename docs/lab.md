# Firebox Lab Architecture

## Topology

```text
                          Internet
                             |
                        Firebox T25
                      /             \
             eth1 - RECOVERY     eth2 - LAN-TRUNK
             10.255.255.1/30            |
                      |           Hyper-V vSwitch
                Admin laptop             |
                10.255.255.2      Windows VLAN vNICs
```

## Networks

| VLAN | Name | Network | Firebox | Zone | Test endpoint |
|---|---|---|---|---|---|
| 10 | CORP | 10.10.10.0/24 | 10.10.10.1 | Trusted | 10.10.10.100 DHCP |
| 20 | SERVERS | 10.20.20.0/24 | 10.20.20.1 | Optional | 10.20.20.2 Static |
| 30 | MANAGEMENT | 10.30.30.0/24 | 10.30.30.1 | Custom | 10.30.30.2 Static |
| 40 | GUEST | 10.40.40.0/24 | 10.40.40.1 | Custom | 10.40.40.100 DHCP |

Firebox `eth2` is the trunk carrying tagged VLANs `10, 20, 30, 40`.

## Hyper-V vSwitch

My PC's 2nd Ethernet NIC is connected to Firebox `eth2`.

Hyper-V has an External vSwitch called `Firebox-Lab` using that NIC.

I made one virtual NIC for each VLAN:

```text
vEthernet (CORP)        VLAN 10
vEthernet (SERVERS)     VLAN 20
vEthernet (MANAGEMENT)  VLAN 30
vEthernet (GUEST)       VLAN 40
```

All VLANs travel through the same physical Ethernet NIC.

```text
Windows
   |
vEthernet (CORP)
   |
Hyper-V tags it VLAN 10
   |
2nd Ethernet NIC
   |
Firebox eth2 trunk
```

The physical NIC is the trunk and Windows sees each VLAN as a separate virtual NIC.

## Recovery

Firebox `eth1` is a separate recovery path if MANAGEMENT or the trunk stops working.

```text
Network:      10.255.255.0/30
Firebox:      10.255.255.1
Admin laptop: 10.255.255.2
Zone:         Custom
DHCP:         Enabled
```

For a dedicated recovery link I would normally use static addresses,
but for this lab I use DHCP so the laptop can still switch between the Firebox and other networks.

## Current Security Design

```text
MANAGEMENT -> Firebox management     ALLOW
RECOVERY   -> Firebox management     ALLOW
CORP       -> Firebox management     DENY
SERVERS    -> Firebox management     DENY
GUEST      -> Firebox management     DENY

CORP       -> Internet               ALLOW
MANAGEMENT -> Internet               ALLOW
GUEST      -> Internet               ALLOW

GUEST      -> CORP                   DENY
GUEST      -> SERVERS                DENY
GUEST      -> MANAGEMENT             DENY
```

# Test Commands

## Check Hyper-V VLANs

```powershell
Get-VMNetworkAdapterVlan -ManagementOS
```

Specific interface:

```powershell
Get-VMNetworkAdapterVlan `
  -ManagementOS `
  -VMNetworkAdapterName "MANAGEMENT"
```

## Check Windows Interfaces

```powershell
Get-NetAdapter
Get-NetIPAddress
ipconfig /all
```

## Check ARP

```powershell
Get-NetNeighbor -InterfaceAlias "vEthernet (MANAGEMENT)"
```

## Ping Firebox from MANAGEMENT

```powershell
ping -S 10.30.30.2 10.30.30.1
```

## Test Web UI from MANAGEMENT

Should work:

```powershell
curl.exe -k --interface 10.30.30.2 https://10.30.30.1:8080
```

## Test SSH from MANAGEMENT

Should work:

```powershell
ssh -b 10.30.30.2 -p 4118 admin@10.30.30.1
```

## Test CORP Management Isolation

Should fail:

```powershell
curl.exe -k --interface 10.10.10.100 https://10.10.10.1:8080
ssh -b 10.10.10.100 -p 4118 admin@10.10.10.1
```

## Test GUEST Management Isolation

Should fail:

```powershell
curl.exe -k --interface 10.40.40.100 https://10.40.40.1:8080
ssh -b 10.40.40.100 -p 4118 admin@10.40.40.1
```

## Test GUEST Internet

```powershell
ping -S 10.40.40.100 1.1.1.1
```

```powershell
curl.exe --interface 10.40.40.100 https://example.com
```
## Lab Scripts

### Show lab status

Shows the VLAN interfaces and their IPv4 addresses.

From Ubuntu/WSL:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$PWD/scripts/Show-LabStatus.ps1")"
```

From Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\wsl.localhost\Ubuntu\home\michael\projects\watchguard-firebox-lab\scripts\Show-LabStatus.ps1"
```

### Test lab

From Ubuntu/WSL:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$PWD/scripts/Test-Lab.ps1")"
```

From Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\wsl.localhost\Ubuntu\home\michael\projects\watchguard-firebox-lab\scripts\Test-Lab.ps1"
```

# Firebox CLI

Connect:

```powershell
ssh -p 4118 admin@10.255.255.1
```

Or through MANAGEMENT:

```powershell
ssh -b 10.30.30.2 -p 4118 admin@10.30.30.1
```

Show VLANs:

```text
show vlan
show vlan CORP
```

Show interface:

```text
show interface 2
```

Show routes:

```text
show ip route
```

Packet capture:

```text
tcpdump -i eth2
```

ICMP only:

```text
tcpdump -i eth2 icmp
```

# Git

Normal workflow:

```bash
git status
git add .
git commit -m "Update"
git push
```

# Testing Limitation

The current CORP, SERVERS, MANAGEMENT and GUEST interfaces are all on the same Windows PC.

Because of that, Windows can sometimes route traffic between them itself instead of sending it through the Firebox.

So these interfaces are good for testing VLANs, DHCP, Internet access and Firebox access, but not for proving CORP-to-SERVERS firewall rules.

For real inter-VLAN testing, use separate VMs or physical hosts so the traffic has to pass through the Firebox.
