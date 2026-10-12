# WatchGuard Firebox Lab

This is just documentation for my WatchGuard (WG) T25 lab.

FYI: This was done after getting my WG's certifications for:
- Network Security Essentials 
- Identity Security Essentials
- Endpoint Security Essentials

This repo will contain:

- Fireware Web UI
- WG System Manager
- Policy Manager
- Firewall policies
- Mobile VPN with SSL
- Mobile VPN with IKEv2
- HTTPS content inspection / HTTPS proxy actions
- Certificates (web server and proxy CA)
- Fireware CLI
- Troubleshooting

The goal of this lab was to test different configurations and different VPNs. 
WG does recommend to mainly use IKEv2 VPN as it is faster and "safer", but they also 
say to have an SSL VPN as backup if IKE doesn't work on public networks like at hotels, 
airport, guest networks... So I tested both VPNs on their strongest encryption 
settings and compared speeds. I also tested with and without HTTPS content 
inspection. 

More details are in `docs/firebox-lab.md`
