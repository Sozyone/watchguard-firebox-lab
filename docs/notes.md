# WatchGuard Firebox Lab Notes

Notes and observations from working with a WatchGuard Firebox T25.

## 1. Initial Firebox Setup

Started by factory resetting the WatchGuard T25.

Initial connection:

```text
Firebox eth1: 10.0.1.1
Web UI: https://10.0.1.1:8080
```

Did the setup wizard with the Firebox as locally managed.

Initial interfaces:

```text
eth0 - External - DHCP
eth1 - Trusted  - 10.0.1.1/24
```

Upgraded Fireware and then moved config work to WatchGuard System Manager and Policy Manager.

## 2. WatchGuard System Manager and Policy Manager

Created both SSL VPN and IKEv2 Mobile VPN from:

```text
VPN -> Mobile VPN -> Get Started
```

Disabled the broad default VPN allow policies.

Instead, added the VPN user groups only to policies they need for more control.

Examples:

```text
HTTP proxy
HTTPS proxy
DNS
Ping
```

Also allowed the VPN groups to access Firebox management services.

VPN groups:

```text
SSLVPN-Users
IKEv2-Users
```

## 3. Mobile VPN with SSL

Authentication uses Firebox-DB.

Created a test user and added it to:

```text
SSLVPN-Users
```

VPN address pool:

```text
192.168.132.0/24
```

Used a less common private subnet to reduce the chance of overlapping with a user's home network.

The SSL VPN uses:

```text
TCP 443 - authentication/control connection
UDP 443 - data channel
```

Using UDP for the data channel avoids TCP-over-TCP and performs better.

If UDP 443 is unavailable, the client can fall back to TCP.

Encryption was configured with AES-GCM 256-bit.

Installed the WatchGuard Mobile VPN with SSL client on Windows and tested connectivity.

The VPN client should be kept updated, especially when WatchGuard PSIRT says so (CVE).

## 4. Mobile VPN with IKEv2

Also made a Mobile VPN with IKEv2.

Authentication and policy access follow the same general principle as SSL VPN.

Address pool:

```text
192.168.122.0/24
```

This is separate from the SSL VPN pool.

IKEv2 normally begins on:

```text
UDP 500
```

During `IKE_SA_INIT`, NAT detection takes place. If NAT is detected, communication moves to:

```text
UDP 4500
```

This is IPsec NAT Traversal, or NAT-T.

Phase 1 configuration used AES-GCM 256-bit and modern Diffie-Hellman groups.

Key groups:

```text
DH-19
DH-20
```

For Phase 2 I enabled PFS and used:

```text
ESP-AES256-GCM
DH-20
```

Installed the generated IKEv2 client profile on Windows using the WatchGuard-generated `.bat` installer.

## 5. HTTPS Proxy and Content Inspection

Configured the HTTPS proxy to use:

```text
Default-HTTPS-Client
```

I tested content inspection.

So the Firebox does:

```text
Client -> encrypted TLS -> Firebox
Firebox -> decrypted inspection
Firebox -> new encrypted TLS -> Internet server
```

Verified inspection by checking certificates.

For inspected sites, the certificate issuer became:

```text
Fireware HTTPS Proxy
```

I also tested from Linux with:

```bash
openssl s_client -connect example.com:443 -servername example.com
```

Some sites continued to show their normal public certificate.

This was caused by predefined Content Inspection Exclusions.

Examples included services from companies such as:

```text
Google
Microsoft
LinkedIn
```

## 6. QUIC / HTTP3 Observation

HTTPS proxy inspection primarily applies to HTTPS over TCP.

Modern browsers can use QUIC / HTTP3 over `UDP 443`

That traffic does not pass through the normal HTTPS TCP proxy in the same way.

For testing, I created an outbound UDP 443 deny policy.

This forced browsers to fall back to HTTPS over TCP, allowing the HTTPS proxy to inspect the connection.

The policy also needed to include VPN user groups when I wanted the same behavior for VPN clients.

This was a lab experiment to understand protocol behavior, not automatically a recommendation for production network.

## 7. Certificates

Two different certificate purposes were important during the lab.

### Firebox Web Server Certificate

This certificate is used when connecting to the Firebox itself.

For example:

```text
https://10.0.1.1:8080
```

Created a custom Web Server certificate called `Lab`

Included the Firebox addresses used for administration.

Exported the certificate and installed it in Windows `Trusted Root Certification Authorities`

This removed the browser warning when accessing the Firebox management interface.

This certificate is not the same one used for HTTPS content inspection.

### Fireware HTTPS Proxy CA

HTTPS inspection uses the `Fireware HTTPS Proxy` certificate authority.

When the Firebox decrypts and inspects HTTPS traffic, it generates a replacement certificate for the destination site and signs it with this CA.

Clients need to trust the Fireware HTTPS Proxy CA.

The certificate can be obtained from the Firebox Certificate Portal:

```text
https://10.0.1.1:4126/certportal
```

I installed it in Windows `Trusted Root Certification Authorities`

Without this CA installed, inspected HTTPS sites generate certificate trust warnings.

## 8. Fireware CLI

Firebox SSH management uses:

```text
TCP 4118
```

Example:

```powershell
ssh -p 4118 admin@10.0.1.1
```

The CLI was useful for:

```text
checking VLANs
checking interfaces
checking routes
packet captures
testing configuration
troubleshooting traffic
```

## 9. Packet Capture

Fireware includes `tcpdump`, which was useful for checking whether packets actually reached an interface.

Example:

```text
tcpdump -i eth2
```

This was especially useful while troubleshooting the MANAGEMENT VLAN.

The capture showed:

```text
ARP request from 10.30.30.2
ARP reply from 10.30.30.1
ICMP echo request from 10.30.30.2
```

That proved Layer 2 and VLAN tagging were working.

The missing ping response was just a firewall policy issue.

After allowing MANAGEMENT to ping the Firebox, the test succeeded.

This was a useful troubleshooting pattern:

```text
1. Check link
2. Check VLAN
3. Check ARP
4. Check IP
5. Check firewall policy
```

## 10. External Port Scan Test

I tested the Firebox externally with Nmap.

I scanned the public IP using common ports and specific WatchGuard management ports including:

```text
4100
4105
4117
4118
4126
8080
```

The Firebox detected the activity as a port scan through Default Threat Protection / Default Packet Handling.

My public IP was temporarily put into `Blocked Sites`

After that, Nmap reported ports as `filtered` or `no-response` because the Firebox was silently dropping the traffic.

TCP 443 remained reachable because it was required by the SSL VPN policy.

This showed the difference between:

```text
a service listening
a firewall policy allowing access
automatic threat protection blocking the source
```

## 11. HTTP Proxy Observation

During HTTPS inspection testing, one site failed because an HTTP proxy response header line exceeded the configured limit.

Increased the maximum response header line length from `4096` to `8192`

After that, the site worked.

This showed that application-layer proxies can block traffic even when basic TCP connectivity is working.

## 12. WSL and Containerlab Experiment

I originally attempted to use WSL and Containerlab to create virtual clients and servers directly attached to the physical Firebox VLANs.

The original idea was:

```text
Containerlab client -> VLAN 10 -> Firebox
Containerlab server -> VLAN 20 -> Firebox
```

WSL was connected through a Hyper-V external switch to the physical Ethernet adapter connected to the Firebox.

Untagged Ethernet connectivity worked correctly.

For example:

```text
WSL 10.0.2.2
Firebox TRANSIT 10.0.2.1
```

This allowed normal routed communication.

However, VLAN subinterfaces created inside WSL did not pass tagged 802.1Q traffic through the WSL / Hyper-V networking path to the physical Firebox trunk.

Because of this, direct Containerlab attachment to the Firebox VLANs was abandoned.

The Containerlab topology and WSL host setup scripts were removed from the repository.

For future virtual clients and servers directly attached to the Firebox trunk, a small Linux Hyper-V VM with a trunked virtual NIC would be a cleaner design.

Containerlab could then run inside that VM and create separate Linux hosts on the real Firebox VLANs.
