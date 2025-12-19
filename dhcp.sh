#!/bin/bash

# ens3 = WAN (NAT/Internet)
# ens4 = LAN1 192.168.102.0/24
# ens5 = LAN2 192.168.101.0/24

apt update
apt install -y isc-dhcp-server iptables iptables-persistent

cp /etc/network/interfaces /etc/network/interfaces.bak
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak 2>/dev/null || true
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak 2>/dev/null || true

cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

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

cat > /etc/default/isc-dhcp-server <<EOF
INTERFACESv4="ens4 ens5"
EOF

cat > /etc/dhcp/dhcpd.conf <<EOF
default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet 192.168.102.0 netmask 255.255.255.0 {
    range 192.168.102.50 192.168.102.100;
    option routers 192.168.102.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}

subnet 192.168.101.0 netmask 255.255.255.0 {
    range 192.168.101.50 192.168.101.100;
    option routers 192.168.101.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

sed -i 's/^\s*net\.ipv4\.ip_forward\s*=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -o ens3 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE

iptables -C FORWARD -i ens3 -o ens4 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i ens3 -o ens4 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -C FORWARD -i ens4 -o ens3 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i ens4 -o ens3 -j ACCEPT

iptables -C FORWARD -i ens3 -o ens5 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i ens3 -o ens5 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -C FORWARD -i ens5 -o ens3 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i ens5 -o ens3 -j ACCEPT

netfilter-persistent save
systemctl enable netfilter-persistent
