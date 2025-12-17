#!/bin/bash

cat > /etc/network/interfaces <<EOF
# loopback
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet dhcp

auto ens4
iface ens4 inet static
    address 192.168.102.1
    netmask 255.255.255.0

auto ens5
iface ens5 inet static
    address 192.168.101.1
    netmask 255.255.255.0
EOF

systemctl restart networking

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -F
iptables -F

iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
iptables -A FORWARD -i ens3 -o ens4 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens4 -o ens3 -j ACCEPT
iptables -A FORWARD -i ens3 -o ens5 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens5 -o ens3 -j ACCEPT
