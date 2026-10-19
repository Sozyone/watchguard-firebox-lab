# WatchGuard Firebox Lab

Lab notes for my WatchGuard T25 after completing the Network Security, Identity Security and Endpoint Security Essentials certifications.

The lab covers VPNs, firewall policies, HTTPS inspection, certificates, CLI troubleshooting and a Containerlab network connected to the physical Firebox.

More details are in `docs/firebox-lab.md`.

## Containerlab

```text
client1 10.10.10.10/24
server1 10.20.20.10/24
        |
r1
├── 10.10.10.1/24
├── 10.20.20.1/24
└── 10.255.0.2/30
        |
WSL 10.255.0.1/30
        |
WSL eth2 10.0.1.2/24
        |
WatchGuard T25 10.0.1.1/24
```

## Start

```bash
cd ~/projects/watchguard-firebox-lab
sudo clab deploy -t containerlab/firebox-lab.clab.yml
./scripts/host-setup.sh
```

## Nodes

```bash
sudo docker ps

sudo docker exec -it clab-firebox-lab-client1 bash
sudo docker exec -it clab-firebox-lab-r1 bash
sudo docker exec -it clab-firebox-lab-server1 bash
```

Use `exit` to leave a node.

##  Destroy and Rebuild

```bash
sudo clab destroy -t containerlab/firebox-lab.clab.yml
sudo clab deploy -t containerlab/firebox-lab.clab.yml
./scripts/host-setup.sh
```

## Git

```bash
git status
git add .
git commit -m "Update lab"
git push
```
