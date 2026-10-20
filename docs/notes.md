# WatchGuard Firebox Lab Notes

These are configuration notes and observations from working with a physical WatchGuard Firebox T25.

Network architecture, VLANs and reusable test commands are documented separately in `lab.md`.

## 1. Initial Firebox Setup

I started by factory resetting the WatchGuard T25.

Initial connection:

```text
Firebox eth1: 10.0.1.1
Web UI: https://10.0.1.1:8080
```

I completed the setup wizard and configured the Firebox as locally managed.

Initial interfaces:

```text
eth0 - External - DHCP
eth1 - Trusted  - 10.0.1.1/24
```

I upgraded Fireware to the latest available version and then moved most configuration work from the Web UI to WatchGuard System Manager and Policy Manager.

## 2. WatchGuard System Manager and Policy Manager

I connected to the Firebox with WSM and used Policy Manager for most configuration.

I created both SSL VPN and IKEv2 Mobile VPN configurations from:

```text
VPN -> Mobile VPN -> Get Started
```

I disabled the broad default VPN allow policies.

Instead, I added the VPN user groups only to policies they actually need.

Examples:

```text
HTTP proxy
HTTPS proxy
DNS
Ping
```

During testing I also allowed the VPN groups to access Firebox management services.

The VPN groups are VPN authentication groups, not normal Firewall groups:

```text
SSLVPN-Users
IKEv2-Users
```

This provides more control than allowing VPN users broadly into the internal network.

## 3. Mobile VPN with SSL

Authentication uses Firebox-DB.

I created a test user and added the user to:

```text
SSLVPN-Users
```

VPN address pool:

```text
192.168.132.0/24
```

I intentionally used a less common private subnet to reduce the chance of overlapping with a user's home network.

The SSL VPN uses:

```text
TCP 443 - authentication/control connection
UDP 443 - data channel
```

Using UDP for the data channel avoids TCP-over-TCP behavior and generally performs better.

If UDP 443 is unavailable, the client can fall back to TCP.

Encryption was configured with AES-GCM 256-bit.

I installed the WatchGuard Mobile VPN with SSL client on Windows and tested connectivity.

The VPN client should be kept updated, especially when WatchGuard publishes security fixes.

## 4. Mobile VPN with IKEv2

I also configured Mobile VPN with IKEv2.

Authentication and policy access follow the same general principle as SSL VPN: users only receive access through policies that explicitly include the IKEv2 group.

Address pool:

```text
192.168.122.0/24
```

This is separate from the SSL VPN pool.

IKEv2 normally begins on:

```text
UDP 500
```

During `IKE_SA_INIT`, NAT detection takes place.

If NAT is detected, communication moves to:

```text
UDP 4500
```

This is IPsec NAT Traversal, or NAT-T.

Phase 1 configuration used AES-GCM 256-bit and modern Diffie-Hellman groups.

Configured key groups included:

```text
DH-19
DH-20
```

For Phase 2 I enabled PFS and used:

```text
ESP-AES256-GCM
DH-20
```

I installed the generated IKEv2 client profile on Windows using the WatchGuard-generated `.bat` installer.

## 5. HTTPS Proxy and Content Inspection

I configured the HTTPS proxy to use:

```text
Default-HTTPS-Client
```

Instead of simply allowing HTTPS traffic, the proxy performs content inspection.

This means the Firebox:

```text
Client -> encrypted TLS -> Firebox
Firebox -> decrypted inspection
Firebox -> new encrypted TLS -> Internet server
```

I verified inspection by checking certificates presented to the client.

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

Modern browsers can use QUIC / HTTP3 over:

```text
UDP 443
```

That traffic does not pass through the normal HTTPS TCP proxy in the same way.

For testing, I created an outbound UDP 443 deny policy.

This forced browsers to fall back to HTTPS over TCP, allowing the HTTPS proxy to inspect the connection.

The policy also needed to include VPN user groups when I wanted the same behavior for VPN clients.

This was a lab experiment to understand protocol behavior, not automatically a recommendation for every production network.

## 7. Certificates

Two different certificate purposes were important during the lab.

### Firebox Web Server Certificate

This certificate is used when connecting to the Firebox itself.

For example:

```text
https://10.0.1.1:8080
```

I created a custom Web Server certificate called:

```text
Lab
```

I included the Firebox addresses used for administration.

I exported the certificate and installed it in Windows:

```text
Trusted Root Certification Authorities
```

This removed the browser warning when accessing the Firebox management interface.

This certificate is not the same certificate used for HTTPS content inspection.

### Fireware HTTPS Proxy CA

HTTPS inspection uses the:

```text
Fireware HTTPS Proxy
```

certificate authority.

When the Firebox decrypts and inspects HTTPS traffic, it generates a replacement certificate for the destination site and signs it with this CA.

Clients therefore need to trust the Fireware HTTPS Proxy CA.

The certificate can be obtained from the Firebox Certificate Portal:

```text
https://10.0.1.1:4126/certportal
```

I installed it in Windows:

```text
Trusted Root Certification Authorities
```

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

One useful lesson was that Fireware CLI syntax does not always behave like Cisco-style CLI.

For example, configuration changes do not always require an `apply` command at the general configuration level.

Another version-specific detail I encountered was static route syntax using:

```text
distance
```

rather than:

```text
metric
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

The missing ping response was therefore a firewall policy issue rather than a VLAN or Hyper-V problem.

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

The scanning public IP was temporarily added to:

```text
Blocked Sites
```

After that, Nmap reported ports as:

```text
filtered
no-response
```

because the Firebox was silently dropping the traffic.

TCP 443 remained reachable because it was required by the SSL VPN policy.

This demonstrated the difference between:

```text
a service listening
a firewall policy allowing access
automatic threat protection blocking the source
```

## 11. HTTP Proxy Observation

During HTTPS inspection testing, one site failed because an HTTP proxy response header line exceeded the configured limit.

The relevant proxy action was:

```text
Default-HTTP-Client
```

I increased the maximum response header line length from:

```text
4096
```

to:

```text
8192
```

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

However, VLAN subinterfaces created inside WSL did not successfully pass tagged 802.1Q traffic through the WSL / Hyper-V networking path to the physical Firebox trunk.

Because of this, direct Containerlab attachment to the Firebox VLANs was abandoned.

The Containerlab topology and WSL host setup scripts were removed from the repository.

For future virtual clients and servers directly attached to the Firebox trunk, a small Linux Hyper-V VM with a trunked virtual NIC would be a cleaner design.

Containerlab could then run inside that VM and create separate Linux hosts on the real Firebox VLANs.

## 13. General Lessons

A few important lessons from the lab so far:

- A successful ARP exchange proves much more than a failed ping alone.
- Custom Firebox zones do not automatically receive Trusted or Optional policy access.
- Management-plane access should use explicit sources instead of broad aliases such as `Any-Trusted`.
- VPN users should receive access through explicit policies rather than broad VPN allow rules.
- HTTPS inspection depends on client trust of the Firebox proxy CA.
- QUIC can bypass a TCP-based HTTPS proxy path.
- Firewall troubleshooting should separate Layer 2, routing, policy and application-layer problems.
- Packet captures are often faster than guessing.
