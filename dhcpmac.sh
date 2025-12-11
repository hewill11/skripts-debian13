#!/bin/bash
apt update
apt install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<EOF
INTERFACESv4="ens3"
EOF

cat > /etc/dhcp/dhcpd.conf <<EOF
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.10.0 netmask 255.255.255.0 {
}

host pc1 {
    hardware ethernet AA:BB:CC:DD:EE:01;
    fixed-address 192.168.10.10;
}

host pc2 {
    hardware ethernet AA:BB:CC:DD:EE:02;
    fixed-address 192.168.10.20;
}
EOF

systemctl restart isc-dhcp-server
