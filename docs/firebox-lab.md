# WatchGuard Firebox Lab

## 1. Initial Firebox Setup
Started the lab by factory resetting the WG T25.  
Connected to my laptop with eth and started Fireware Web UI on browser 10.0.1.1:8080.  
I then did the setup wizard. Set the Firebox (FB) to locally-managed.

- Eth0 is External and on DHCP
- Eth1 is Trusted network is 10.0.1.0/24 so eth1 on FB is 10.0.1.1

I also upgraded the FB firmware to latest version from the web UI.  
After this, I left the browser and went to WSM.

## 2. WSM and Policy Manager
Connected to the FB with WSM. I used Policy Manager for most of the configuration.

I first  made the SSL and IKEv2 VPNs from `VPN - Mobile VPN - Get Started...`  
More details in sections below.

I also disabled the default broad VPN policies.  
Instead, I added the VPN user groups (of type SSL or IKEv2, NOT Firewall) to 
the policies they need only:

- HTTP proxy
- HTTPS proxy
- DNS
- Ping

I also added them to Firebox Web UI and WatchGuard management for testing purposes
while I am configuring the FB.

## 3. Mobile VPN with SSL
I used Firebox-DB for authentication and created a test user and added it 
to the `SSLVPN-Users` group.

The SSL VPN's virtual address pool is `192.168.132.0/24` since it needs 
to be different from possible usual home networks for it to work.

I have TCP 443 as authentication channel and UPD 443 as data channel.
UPD 443 makes the VPN faster which I tested, instead of being TCP over TCP. 
I also set the encryption to AES-GCM (256-bit). 

UDP 443 is used by QUIC / HTTP3 which most of the internet allow, so that port 
is usually open and not blocked. If UDP 443 is blocked, then it is fine to switch 
the data channel back to TCP 443, but the VPN will be slower. A firewall out there 
could also specifically inspect and block VPN traffic even when it uses TCP 443, 
so neither option is guaranteed to work everywhere.  

I also installed the WG Mobile VPN with SSL client on my PC.  
IMPORTANT!! This client needs to be updated every few months and if a CVE is found. 

## 4. Mobile VPN with IKEv2
I did the same as above for the  IKev2 VPN (auth, user group, policies).

The IKEv2 VPN's address pool is `192.168.122.0/24`. Seperate from SSL pool.

`IKE_SA_INIT` starts on UDP 500 and detects NAT. If NAT is detected, IKE switches 
to UDP 4500 using NAT-T.

In the FB, I set the Phase 1 Transforms to AES-GCM (256-bit) and Key Group to 
DH-19 and DH-20. For Phase 2, I checked PFS and DH-20 with ESP-AES256-GCM.

I also installed the client profile using the bat file to my PC.

## 5. HTTPS Proxy and Content Inspection
I set the HTTPS proxy to Default-HTTPS-Client and to inspect traffic instead of 
allowing it. So now the FB decrypts the TLS connection and inspects it.

I tested this by checking website certificates and seeing `Fireware HTTPS Proxy` 
instead of the site's normal public CA. I also tested this from WSL with:

`openssl s_client -connect example.com:443 -servername example.com`

This showed that `example.com` was being re-signed by the Fireware HTTPS Proxy CA.

Some sites like Google, Microsoft, LinkedIn, and others were still showing their 
normal public certificates. This was because of the predefined 
`Content Inspection Exclusions`.

It also seems that QUIC (UDP 443) doesn't go through the HTTPS proxy since it 
handles TCP 443. I made a custom UDP 443 deny outgoing policy to test this and force 
browsers back to TCP so the HTTPS proxy can inspect the connection. That policy also 
needs to include `SSLVPN-Users` and `IKEv2-Users`.

## 6. Certificates

To remove warnings in browsers, I installed two different certificats during the lab.

### Firebox Web Server Certificate

I created a custom Web Server certificate to remove browser warning when connecting 
to the Firebox on `10.0.1.1:8080` from `Setup - Certificates - Firebox Web Server Certificate`.

I made one called `Lab` and added the FB IPs I use to connect to it. I exported 
`Lab.pem` from the FB and installed it in my PC's `Trusted Root Certification Authorities` 
store. This is not to CA used for content inspection.

### Fireware Https Proxy CA
HTTPS inspection uses a different certificate called `Fireware HTTPS Proxy` CA.

Without it, inspected websites show warnings because the FB decrypts and re-signs 
the traffic with certificates that the clients don't trust. 

It can be downloaded from the Certification Portal:  
`10.0.1.1:4126/certportal`. It should then be installed in Windows' 
`Trusted Root Certification Authorities`.

## 7. Fireware CLI

## 8. Troubleshooting and Tests

### External port scan test

I tested the FB externally using Nmap to see what would happen.

I scanned the public IP for 500 top ports and also: TCP 4100, 4105, 4117, 4118, 4126, 8080.

The FB's Default Threat Protection / Default Packet Handling detected the scan
as a port scan attack and temporarily blocked my host's public IP. It could then
be seen in `Blocked Sites`.

After that, Nmap started showing the ports as `filtered` / `no-response`
because the FB was silently dropping traffic.

I could see that TCP 443 was open because of the needed SSL VPN policy.
