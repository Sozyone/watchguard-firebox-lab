#!/usr/bin/env bash
set -e

# WSL side of the r1 transit link
sudo ip link set r1-t25 up
sudo ip addr replace 10.255.0.1/30 dev r1-t25

# Enable routing in WSL
sudo sysctl -w net.ipv4.ip_forward=1

# Routes back to Containerlab networks through r1
sudo ip route replace 10.10.10.0/24 via 10.255.0.2 dev r1-t25
sudo ip route replace 10.20.20.0/24 via 10.255.0.2 dev r1-t25

# Allow Containerlab networks toward the Firebox LAN
for NET in 10.255.0.0/30 10.10.10.0/24 10.20.20.0/24; do
    sudo iptables -C DOCKER-USER \
        -i r1-t25 -o eth2 \
        -s "$NET" -d 10.0.1.0/24 \
        -j ACCEPT 2>/dev/null || \
    sudo iptables -I DOCKER-USER 1 \
        -i r1-t25 -o eth2 \
        -s "$NET" -d 10.0.1.0/24 \
        -j ACCEPT

    sudo iptables -C DOCKER-USER \
        -i eth2 -o r1-t25 \
        -s 10.0.1.0/24 -d "$NET" \
        -m conntrack --ctstate ESTABLISHED,RELATED \
        -j ACCEPT 2>/dev/null || \
    sudo iptables -I DOCKER-USER 1 \
        -i eth2 -o r1-t25 \
        -s 10.0.1.0/24 -d "$NET" \
        -m conntrack --ctstate ESTABLISHED,RELATED \
        -j ACCEPT
done
