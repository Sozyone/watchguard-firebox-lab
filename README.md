# WatchGuard Firebox Lab

Hands-on lab built around a physical WatchGuard Firebox T25.

## Current network

| VLAN | Name | Network | Zone |
|---|---|---|---|
| 10 | CORP | 10.10.10.0/24 | Trusted |
| 20 | SERVERS | 10.20.20.0/24 | Optional |
| 30 | MANAGEMENT | 10.30.30.0/24 | Custom |
| 40 | GUEST | 10.40.40.0/24 | Custom |
| 99 | TRANSIT | 10.0.2.0/24 | Trusted |

Firebox `eth2` is the `LAN-TRUNK`.

VLANs 10, 20, 30 and 40 are tagged.
VLAN 99 is untagged.

## Lab topics

- VLAN segmentation
- DHCP
- Firewall policies
- Guest isolation
- Management-plane isolation
- HTTPS inspection
- Certificates
- SSL VPN
- IKEv2
- CLI troubleshooting
- Packet captures
- Traffic Monitor analysis

## Management

Management VLAN:

```text
10.30.30.0/24
Firebox: 10.30.30.1
```

Recovery/admin network:

```text
10.0.1.0/24
Firebox: 10.0.1.1
```

## Goal

Build and troubleshoot a realistic small-business network using a physical WatchGuard Firebox.
