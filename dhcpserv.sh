#!/usr/bin/env bash
set -e

cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet dhcp

auto ens4
iface ens4 inet static
    address 192.168.100.1
    netmask 255.255.255.0

auto ens5
iface ens5 inet static
    address 192.168.101.1
    netmask 255.255.255.0
EOF

apt update
apt install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="ens4 ens5"
EOF

cat > /etc/dhcp/dhcpd.conf <<'EOF'
default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet 192.168.100.0 netmask 255.255.255.0 {
    range 192.168.100.50 192.168.100.100;
    option routers 192.168.100.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8;
}

subnet 192.168.101.0 netmask 255.255.255.0 {
    range 192.168.101.50 192.168.101.100;
    option routers 192.168.101.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8;
}
EOF

systemctl restart networking
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl enable isc-dhcp-server
systemctl restart isc-dhcp-server
systemctl --no-pager status isc-dhcp-server
