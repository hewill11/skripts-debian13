#!/usr/bin/env bash
set -euo pipefail

LAN_IF="ens4"
WAN_IF="ens3"
LAN_IP="192.168.100.1"
LAN_NET="192.168.100.0"
LAN_MASK="255.255.255.0"
CLIENT_IP="192.168.100.10"
DNS_IP="8.8.8.8"
CLIENT1_MAC="REPLACE_ME_WITH_CLIENT1_MAC"

install -d -m 0755 /root/backup
cp -a /etc/network/interfaces "/root/backup/interfaces.$(date +%F_%H%M%S)" 2>/dev/null || true
cp -a /etc/default/isc-dhcp-server "/root/backup/isc-dhcp-server.$(date +%F_%H%M%S)" 2>/dev/null || true
cp -a /etc/dhcp/dhcpd.conf "/root/backup/dhcpd.conf.$(date +%F_%H%M%S)" 2>/dev/null || true

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${WAN_IF}
iface ${WAN_IF} inet dhcp

auto ${LAN_IF}
iface ${LAN_IF} inet static
    address ${LAN_IP}
    netmask ${LAN_MASK}
EOF

apt-get update -y
apt-get install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<EOF
INTERFACESv4="${LAN_IF}"
EOF

install -d -m 0755 /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases
chmod 0644 /var/lib/dhcp/dhcpd.leases

cat > /etc/dhcp/dhcpd.conf <<EOF
default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet ${LAN_NET} netmask ${LAN_MASK} {
    option routers ${LAN_IP};
    option subnet-mask ${LAN_MASK};
    option domain-name-servers ${DNS_IP};

    deny unknown-clients;

    host client1 {
        hardware ethernet ${CLIENT1_MAC};
        fixed-address ${CLIENT_IP};
    }
}
EOF

systemctl restart networking
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl enable --now isc-dhcp-server
systemctl restart isc-dhcp-server

systemctl --no-pager status isc-dhcp-server
