# Firebox Lab Architecture

## Topology

```text
                         Internet
                            |
                        Firebox T25
                            |
                    eth2 - LAN-TRUNK
                            |
                     Hyper-V vSwitch
                            |
              Windows VLAN test interfaces
```

## Networks

| VLAN | Name | Network | Firebox | Zone |
|---|---|---|---|---|
| 10 | CORP | 10.10.10.0/24 | 10.10.10.1 | Trusted |
| 20 | SERVERS | 10.20.20.0/24 | 10.20.20.1 | Optional |
| 30 | MANAGEMENT | 10.30.30.0/24 | 10.30.30.1 | Custom |
| 40 | GUEST | 10.40.40.0/24 | 10.40.40.1 | Custom |

`eth2` is named `LAN-TRUNK`.

Tagged VLANs: `10 - 20 - 30 - 40`

## Test Clients

```text
CORP        10.10.10.100   DHCP
SERVERS     10.20.20.2     Static
MANAGEMENT  10.30.30.2     Static
GUEST       10.40.40.100   DHCP
```

## Current Security Design

```text
MANAGEMENT -> Firebox management     ALLOW
CORP       -> Firebox management     DENY
SERVERS    -> Firebox management     DENY
GUEST      -> Firebox management     DENY

GUEST -> Internet                    ALLOW
GUEST -> CORP                        DENY
GUEST -> SERVERS                     DENY
GUEST -> MANAGEMENT                  DENY
```

`10.0.1.2` remains an additional recovery/admin host on `eth1`.

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

# Firebox CLI

Connect:

```powershell
ssh -p 4118 admin@10.0.1.1
```

Or through MANAGEMENT:

```powershell
ssh -b 10.30.30.2 -p 4118 admin@10.30.30.1
```

Show VLANs:

```text
show vlan
show vlan CORP
show vlan SERVERS
show vlan MANAGEMENT
show vlan GUEST
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
git commit -m "Describe what changed"
git push
```

Check changes:

```bash
git diff
git diff --cached
```

Recent commits:

```bash
git log --oneline -10
```

Restore an unstaged file:

```bash
git restore filename
```

Unstage a file:

```bash
git restore --staged filename
```

# Testing Limitation

The current CORP, SERVERS, MANAGEMENT and GUEST test interfaces exist on the same
Windows host.

Windows can route traffic locally between its own interfaces, so this setup should
not be used as proof of CORP-to-SERVERS inter-VLAN firewall enforcement.

Testing access to the Firebox itself and testing Internet access from specific
VLAN source addresses is valid.

For true virtual clients and servers on separate VLANs, use separate VMs or physical
hosts so traffic must traverse the Firebox.
