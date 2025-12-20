#!/usr/bin/env bash
set -euo pipefail

WAN_IF="ens3"
TRUNK_IF="ens4"

VLAN100_IP="192.168.100.1/24"
VLAN200_IP="192.168.200.1/24"
VLAN999_IP="192.168.99.1/24"

export DEBIAN_FRONTEND=noninteractive

apt update -y
apt install -y vlan iptables iptables-persistent

modprobe 8021q || true

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${WAN_IF}
iface ${WAN_IF} inet dhcp

auto ${TRUNK_IF}
iface ${TRUNK_IF} inet manual

auto ${TRUNK_IF}.100
iface ${TRUNK_IF}.100 inet static
  address ${VLAN100_IP}

auto ${TRUNK_IF}.200
iface ${TRUNK_IF}.200 inet static
  address ${VLAN200_IP}

auto ${TRUNK_IF}.999
iface ${TRUNK_IF}.999 inet static
  address ${VLAN999_IP}
EOF

if grep -qE '^\s*net\.ipv4\.ip_forward\s*=' /etc/sysctl.conf; then
  sed -i 's/^\s*net\.ipv4\.ip_forward\s*=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
else
  printf '\nnet.ipv4.ip_forward=1\n' >> /etc/sysctl.conf
fi
sysctl -p >/dev/null

systemctl restart networking

iptables -t nat -C POSTROUTING -o "${WAN_IF}" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o "${WAN_IF}" -j MASQUERADE

iptables -C FORWARD -i "${TRUNK_IF}" -o "${WAN_IF}" -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "${TRUNK_IF}" -o "${WAN_IF}" -j ACCEPT

iptables -C FORWARD -i "${WAN_IF}" -o "${TRUNK_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "${WAN_IF}" -o "${TRUNK_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables-save > /etc/iptables/rules.v4

#После последнего скрипта пишем следующие настрйоки для сервера и клиента
# server                         client
# auto lo                        auto lo
# iface lo inet loopback         iface lo inet loopback

# auto ens3                      auto ens3
# iface ens3 inet static         iface ens3 inet static
#   address 192.168.100.10/24    address 192.168.200.10/24
#   gateway 192.168.100.1        gateway 192.168.200.1
#   dns-nameservers 8.8.8.8      dns-nameservers 8.8.8.8
