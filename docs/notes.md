# WatchGuard Firebox Lab Notes

Notes and observations from working with a WatchGuard Firebox T25.

## 1. Initial Setup

Factory reset the T25, ran the setup wizard and set it as locally managed.
Later the network was redesigned with VLANs.

## 2. VPN

Configured both Mobile VPN with SSL and IKEv2 using Firebox-DB users.

Pools:

```text
SSL VPN   192.168.132.0/24
IKEv2     192.168.122.0/24
```

Disabled the broad default VPN policies. Instead added VPN users to policies they need.

### SSL VPN

Configured:

```text
TCP 443 - authentication/control
UDP 443 - data channel
```

UDP avoids TCP-over-TCP and performs better.

Encryption uses AES-GCM 256-bit.

Installed the WatchGuard Mobile VPN with SSL client on Windows.

The VPN client should be kept updated, especially when WatchGuard PSIRT says so (CVE).

### IKEv2

Configured:

```text
Phase 1: AES-GCM 256
DH-19 / DH-20

Phase 2:
ESP-AES256-GCM
PFS
DH-20
```
Installed the generated IKEv2 client profile on Windows using the `.bat` installer.

I tested both VPNs externally from the RDATA network.

Both successfully reached the MANAGEMENT network and Firebox Web UI.

## 3. HTTPS Proxy

Tested HTTPS content inspection with `Default-HTTPS-Client`.

When inspection was enabled, inspected sites were re-signed by `Fireware HTTPS Proxy`

Tested from Linux with:

```bash
openssl s_client -connect example.com:443 -servername example.com
```

Some sites were excluded by WatchGuard's predefined Content Inspection Exclusions.

I later decided not to use TLS inspection for my small-business design, but still use proxy policies.

Inspection has too many downsides, the plan is instead to rely more on:

```text
Endpoint security / EPDR
MFA
Basic Firebox functions
```

No inspection means Firebox AV/IAV/IPS/APT-Blocker/App Control don't work well at all, but EPDR can do a very similar job.

Then the network stays faster, Firebox uses way less ressources, don't need to care about the QUIC/HTTP3 proxy/inspect bypass.

So yeah, most Firebox features are kind of useless for small businesses with low threat levels. Just use strong EPDR and MFA.
Not everyone should go Palo Alto-level extreme security. Inspect and deny everything is not realistic for most SMEs.  

## 4. QUIC / HTTP3

HTTPS proxy inspection primarily applies to HTTPS over TCP, but browsers can also use QUIC / HTTP3 over `UDP 443`

That traffic does not pass through the HTTPS TCP proxy in the same way.

I tested blocking UDP 443, which forced browsers back to TCP 443 so HTTPS inspection worked.

I removed this afterward because I am not using TLS inspection in the final design.

## 5. Certificates

There are two different certificate purposes.

### Web Server Certificate

Used for the Firebox management interface.

I created a custom certificate called `Lab` and trusted it in Windows.

This removed the browser warning when accessing the Firebox management interface.

### Fireware HTTPS Proxy CA

Used only when HTTPS content inspection is enabled.

Clients must trust this CA or inspected sites show certificate warnings.

Certificate Portal:

```text
https://<firebox-ip>:4126/certportal
```

## 6. Troubleshooting Observations

### MANAGEMENT VLAN

MANAGEMENT could not ping the Firebox at first.

`tcpdump` on `eth2` showed:

```text
ARP request from 10.30.30.2
ARP reply from 10.30.30.1
ICMP echo request from 10.30.30.2
```

So the VLAN, trunk and ARP were working.

The Firebox received the ping but no policy allowed it. After adding the Ping policy, it worked.

### Port Scan

I scanned the Firebox externally with Nmap.

Default Threat Protection detected the scan and temporarily added my public IP to `Blocked Sites`.

After that the ports appeared as:

```text
filtered
no-response
```

TCP 443 remained reachable because SSL VPN needed it.

### HTTP Proxy

One site failed because the HTTP proxy response header line limit was too small.

Changed:

```text
4096 -> 8192
```

and the site worked.

## 7. WSL / Containerlab

Tried using WSL and Containerlab to create virtual clients and servers directly on the Firebox VLANs.

Untagged traffic worked, but tagged 802.1Q traffic did not pass correctly through the WSL / Hyper-V networking path.

I removed the Containerlab setup.

The better design is to use separate Hyper-V VMs connected directly to the `Firebox-Lab` vSwitch and assign each VM to a VLAN.
