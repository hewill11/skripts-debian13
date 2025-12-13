#!/usr/bin/env bash
set -e

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet dhcp

auto ens4
iface ens4 inet static
    address 192.168.100.1
    netmask 255.255.255.0
EOF

apt update
apt install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<EOF
INTERFACESv4="ens4"
EOF

cat > /etc/dhcp/dhcpd.conf <<EOF
default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet 192.168.100.0 netmask 255.255.255.0 {
    option routers 192.168.100.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 8.8.8.8;

    deny unknown-clients;

    host client1 {
        hardware ethernet XX:XX:XX:XX:XX:XX;
        fixed-address 192.168.100.10;
    }
}
EOF

systemctl restart networking
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl enable isc-dhcp-server
systemctl restart isc-dhcp-server
